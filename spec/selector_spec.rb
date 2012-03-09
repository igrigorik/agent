require "spec_helper"

describe Agent::Selector do
  # A "select" statement chooses which of a set of possible communications will
  # proceed. It looks similar to a "switch" statement but with the cases all
  # referring to communication operations.
  #   - http://golang.org/doc/go_spec.html#Select_statements

  let(:c) { Agent::Channel.new(:name => :selectable, :type => Integer, :size => 1) }

  it "should yield Selector on select call" do
    select {|s| s.should be_kind_of Agent::Selector}
  end

  it "should evaluate select statements top to bottom" do
    select do |s|
      s.case(c, :send) {}
      s.case(c, :receive) {}
      s.cases.size.should == 2
    end
  end

  it "should evaluate but skip empty cases" do
    select do |s|
      s.case(c, :send)
      s.cases.size.should == 0
    end
  end

  it "should return immediately on empty select block" do
    s = Time.now.to_f
    select {}

    (Time.now.to_f - s).should be_within(0.05).of(0)
  end

  it "should scan all cases to identify available actions and execute first available one" do
    r = []
    c.send 1

    select do |s|
      s.case(c, :send)    { r.push 1 }
      s.case(c, :receive) { r.push 2 }
      s.case(c, :receive) { r.push 3 }
    end

    r.size.should == 1
    r.first.should == 2
  end

  it "should evaluate default case immediately if no other cases match" do
    r = []
    select do |s|
      s.case(c, :send) { r.push 1 }
      s.default { r.push :default }
    end

    r.size.should == 1
    r.first.should == :default
  end

  it "should timeout select statement" do
    r, s = [], Time.now.to_f
    select do |s|
      s.timeout(0.1) { r.push :timeout }
    end

    r.first.should == :timeout
    (Time.now.to_f - s).should be_within(0.05).of(0.1)
  end

  context "select immediately available channel" do
    it "should select read channel" do
      c = Agent::Channel.new(:name => :select_read, :type => Integer, :size => 1)
      c.send 1

      r = []
      select do |s|
        s.case(c, :send) { r.push :send }
        s.case(c, :receive) { r.push :receive }
        s.default { r.push :empty }
      end

      r.size.should == 1
      r.first.should == :receive
      c.close
    end

    it "should select write channel" do
      c = Agent::Channel.new(:name => :select_write, :type => Integer, :size => 1)

      r = []
      select do |s|
        s.case(c, :send) { r.push :send }
        s.case(c, :receive) { r.push :receive }
        s.default { r.push :empty }
      end

      r.size.should == 1
      r.first.should == :send
      c.close
    end
  end

  context "select busy channel" do
    it "should select busy read channel" do
      c = Agent::Channel.new(:name => :select_read, :type => Integer, :size => 1)
      r = []

      # brittle.. counting on select to execute within 0.5s
      s = Time.now.to_f
      go(c) { |r| sleep(0.2); r.send 1 }

      select do |s|
        s.case(c, :receive) { r.push c.receive }
      end

      r.size.should == 1
      (Time.now.to_f - s).should be_within(0.1).of(0.2)
      c.close
    end

    it "should select busy write channel" do
      c = Agent::Channel.new(:name => :select_write, :type => Integer, :size => 1)
      c.send 1

      # brittle.. counting on select to execute within 0.5s
      s = Time.now.to_f
      go(c) { |r| sleep(0.2); r.receive }

      select do |s|
        s.case(c, :send) { c.send 2 }
      end

      c.receive.should == 2
      (Time.now.to_f - s).should be_within(0.1).of(0.2)
      c.close
    end

    it "should select first available channel" do
      # create a "full" write channel, and "empty" read channel
      cw = Agent::Channel.new(:name => :select_write, :type => Integer, :size => 1)
      cr = Agent::Channel.new(:name => :select_read,  :type => Integer, :size => 1)

      cw.send 1
      res = []

      # empty read channel will wait for 1s before pushing a message into it
      # full write channel will wait for 0.8s before consuming the message
      s = Time.now.to_f
      go(cr) { |r| sleep(0.5); r.send 2 }
      go(cw) { |w| sleep(0.2); res.push w.receive }

      # wait until one of the channels become available
      # cw should fire first and push '3'
      select do |s|
        s.case(cr, :receive) { |c| res.push c.receive }
        s.case(cw, :send) { |c| c.send 3 }
      end

      # 0.8s goroutine should have consumed the message first
      res.size.should == 1
      res.first.should == 1

      # send case should have fired, and we should have a message
      cw.receive.should == 3

      (Time.now.to_f - s).should be_within(0.1).of(0.2)
      cw.close
      cr.close
    end

    # TODO: r.send 2 on a closed channel - raise error?
  end

end
