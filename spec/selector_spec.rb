require "spec_helper"

describe Agent::Selector do
  # A "select" statement chooses which of a set of possible communications will
  # proceed. It looks similar to a "switch" statement but with the cases all
  # referring to communication operations.
  #   - http://golang.org/doc/go_spec.html#Select_statements

  it "should yield Selector on select call" do
    select! {|s| s.should be_kind_of Agent::Selector}
  end

  it "should return immediately on empty select block" do
    s = Time.now.to_f
    select! {}

    (Time.now.to_f - s).should be_within(0.05).of(0)
  end

  it "should timeout select statement" do
    r, now = [], Time.now.to_f
    select! do |s|
      s.timeout(0.1) { r.push :timeout }
    end

    r.first.should == :timeout
    (Time.now.to_f - now).should be_within(0.05).of(0.1)
  end

  context "with unbuffered channels" do
    before do
      @c = channel!(:type => Integer)
    end

    after do
      @c.close
    end

    it "should evaluate select statements top to bottom" do
      select! do |s|
        s.case(@c, :send, 1) {}
        s.case(@c, :receive) {}
        s.default {}
        s.cases.size.should == 3
      end
    end

    it "should raise an error when a block is missing on receive" do
      lambda {
        select! do |s|
          s.case(@c, :receive)
        end
      }.should raise_error(Agent::BlockMissing)
    end

    it "should not raise an error when a block is missing on send" do
      lambda {
        go!{ @c.receive }

        select! do |s|
          s.case(@c, :send, 1)
          s.cases.size.should == 0
        end
      }.should_not raise_error(Agent::BlockMissing)
    end

    it "should scan all cases to identify available actions and execute first available one" do
      r = []
      go!{ @c.send 1 }

      sleep 0.01 # make sure the goroutine executes, brittle

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.case(@c, :receive) { r.push 2 }
        s.case(@c, :receive) { r.push 3 }
      end

      r.size.should == 1
      r.first.should == 2
    end

    it "should evaluate default case immediately if no other cases match" do
      r = []

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.default { r.push :default }
      end

      r.size.should == 1
      r.first.should == :default
    end

    context "select immediately available channel" do
      it "should select read channel" do
        c = channel!(:type => Integer)
        go!{ c.send(1) }

        sleep 0.01 # make sure the goroutine executes, brittle

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        r.size.should == 1
        r.first.should == :receive
        c.close
      end

      it "should select write channel" do
        c = channel!(:type => Integer)

        go!{ c.receive }

        sleep 0.01 # make sure the goroutine executes, brittle

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
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
        c = channel!(:type => Integer)
        r = []

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{ sleep(0.2); c.send 1 }

        select! do |s|
          s.case(c, :receive) {|value| r.push value }
        end

        r.size.should == 1
        (Time.now.to_f - now).should be_within(0.1).of(0.2)
        c.close
      end

      it "should select busy write channel" do
        c = channel!(:type => Integer)

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{sleep(0.2); c.receive[0].should == 2 }

        select! do |s|
          s.case(c, :send, 2) {}
        end

        (Time.now.to_f - now).should be_within(0.1).of(0.2)
        c.close
      end

      it "should select first available channel" do
        # create a write channel and a read channel
        cw  = channel!(:type => Integer)
        cr  = channel!(:type => Integer)
        ack = channel!(:type => TrueClass)

        res = []

        now = Time.now.to_f

        # read channel: wait for 0.3s before pushing a message into it
        go!{ sleep(0.3); cr.send 2 }
        # write channel: wait for 0.1s before consuming the message
        go!{ sleep(0.1); res.push cw.receive[0]; ack.send(true) }

        # wait until one of the channels become available
        # cw should fire first and push '3'
        select! do |s|
          s.case(cr, :receive) {|value| res.push value }
          s.case(cw, :send, 3)
        end

        ack.receive

        res.size.should == 1
        res.first.should == 3

        # 0.3s goroutine should eventually fire
        cr.receive[0].should == 2

        (Time.now.to_f - now).should be_within(0.05).of(0.3)
        cw.close
        cr.close
      end
    end
  end

  context "with buffered channels" do
    before do
      @c = channel!(:type => Integer, :size => 1)
    end

    after do
      @c.close
    end

    it "should evaluate select statements top to bottom" do
      select! do |s|
        s.case(@c, :send, 1) {}
        s.case(@c, :receive) {}
        s.cases.size.should == 2
      end
    end

    it "should raise an error when a block is missing on receive" do
      lambda {
        select! do |s|
          s.case(@c, :receive)
          s.cases.size.should == 0
        end
      }.should raise_error(Agent::BlockMissing)
    end

    it "should not raise an error when a block is missing on send" do
      lambda {
        select! do |s|
          s.case(@c, :send, 1)
          s.cases.size.should == 0
        end
      }.should_not raise_error(Agent::BlockMissing)
    end

    it "should scan all cases to identify available actions and execute first available one" do
      r = []
      @c.send 1

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.case(@c, :receive) { r.push 2 }
        s.case(@c, :receive) { r.push 3 }
      end

      r.size.should == 1
      r.first.should == 2
    end

    it "should evaluate default case immediately if no other cases match" do
      r = []

      @c.send(1)

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.default { r.push :default }
      end

      r.size.should == 1
      r.first.should == :default
    end

    context "select immediately available channel" do
      it "should select read channel" do
        c = channel!(:type => Integer, :size => 1)
        c.send(1)

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        r.size.should == 1
        r.first.should == :receive
        c.close
      end

      it "should select write channel" do
        c = channel!(:type => Integer, :size => 1)

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
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
        c = channel!(:type => Integer, :size => 1)
        r = []

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{ sleep(0.2); c.send 1 }

        select! do |s|
          s.case(c, :receive) {|value| r.push value }
        end

        r.size.should == 1
        (Time.now.to_f - now).should be_within(0.1).of(0.2)
        c.close
      end

      it "should select busy write channel" do
        c = channel!(:type => Integer, :size => 1)
        c.send 1

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{sleep(0.2); c.receive }

        select! do |s|
          s.case(c, :send, 2) {}
        end

        c.receive[0].should == 2
        (Time.now.to_f - now).should be_within(0.1).of(0.2)
        c.close
      end

      it "should select first available channel" do
        # create a "full" write channel, and "empty" read channel
        cw = channel!(:type => Integer, :size => 1)
        cr = channel!(:type => Integer, :size => 1)

        cw.send(1)

        res = []

        now = Time.now.to_f
        # empty read channel: wait for 0.5s before pushing a message into it
        go!{ sleep(0.5); cr.send(2) }
        # full write channel: wait for 0.2s before consuming the message
        go!{ sleep(0.2); res.push cw.receive[0] }

        # wait until one of the channels become available
        # cw should fire first and push '3'
        select! do |s|
          s.case(cr, :receive) {|value| res.push value }
          s.case(cw, :send, 3)
        end

        # 0.8s goroutine should have consumed the message first
        res.size.should == 1
        res.first.should == 1

        # send case should have fired, and we should have a message
        cw.receive[0].should == 3

        (Time.now.to_f - now).should be_within(0.1).of(0.2)
        cw.close
        cr.close
      end
    end
  end

end
