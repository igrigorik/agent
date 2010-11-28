require 'helper'

describe Agent::Selector do

  let(:c) { Agent::Channel.new(:name => "selectable", :type => Integer, :size => 1) }

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
    s = Time.now.to_i
    select {}

    (Time.now.to_i - s).should be_within(0.05).of(0)
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

  context "select immediately available channel" do
    it "should select read channel" do
      c = Agent::Channel.new(:name => "select-read", :type => Integer, :size => 1)
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
      c = Agent::Channel.new(:name => "select-write", :type => Integer, :size => 1)

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
      c = Agent::Channel.new(:name => "select-read", :type => Integer, :size => 1)
      r = []

      # brittle.. counting on select to execute within 0.5s
      s = Time.now.to_i
      go(c) { |r| sleep(1); r.send 1 }

      select do |s|
        s.case(c, :receive) { r.push c.receive }
      end

      r.size.should == 1
      (Time.now.to_i - s).should be_within(0.1).of(1)
      c.close
    end

    it "should select busy write channel" do
      pending('oi, this is a tricky one...')

      # problem:
      # for read-only channel, life is simple
      #  - to_io method on channel and return the read pipe
      #  - calling select returns channel when there is available data in it
      #
      # for read-write, we also need to pass a "writable io" to it
      #  - can't do to_io on channel anymore, need to split into distinct cases
      #  - IO.pipe provides a selectable, but no buffer control.. aka, always writable. bah!
      #   - can't control the pipe buffer size... hardwired into kernel
      #
      #   - write own selectable? event loop / listener? blah..

      c = Agent::Channel.new(:name => "select-write", :type => Integer, :size => 1)
      c.send 1

      # brittle.. counting on select to execute within 0.5s
      s = Time.now.to_i
      go(c) { |r| sleep(1); p [:go_chan, r.receive] }

      select do |s|
        s.case(c, :send) { c.send 2 }
      end

      c.receive.should == 2
      (Time.now.to_i - s).should be_within(0.1).of(1)
      c.close
    end
  end

end
