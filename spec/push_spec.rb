require "spec_helper"

describe Agent::Push do

  context "in its basic operation" do
    before do
      @push = Agent::Push.new("1")
      @ack = channel!(:type => Time)
    end

    it "should close" do
      @push.should_not be_closed
      @push.close
      @push.should be_closed
    end

    it "should run multiple times" do
      i = 0
      @push.receive{|v| i += 1 }
      @push.should be_sent
      @push.receive{|v| i += 1 }
      i.should == 2
    end

    it "should continue when sent" do
      go!{ @push.wait; @ack.send(Time.now) }
      sleep 0.2
      @push.receive{|v|}

      s, _ = @ack.receive

      (Time.now - s).should be_within(0.01).of(0)
    end

    it "should raise an error on the waiter when closed" do
      go!{ sleep 0.1; @push.close }
      lambda{ @push.wait }.should raise_error(Agent::ChannelClosed)
    end
  end

  context "with a blocking_once" do
    before do
      @blocking_once = Agent::BlockingOnce.new
      @push = Agent::Push.new("1", :blocking_once => @blocking_once)
    end

    it "should only send only once" do
      i = 0

      @blocking_once.should_not be_performed
      @push.receive{|v| i += 1 }
      @push.should be_sent
      @blocking_once.should be_performed

      @push.receive{|v| i += 1 }
      i.should == 1

      lambda{@push.receive{raise "an error"} }.should_not raise_error
    end
  end

  context "with a notifier" do
    before do
      @notifier = Agent::Notifier.new
      @push = Agent::Push.new("1", :notifier => @notifier)
    end

    it "should notify when being sent" do
      @notifier.should_not be_notified
      @push.receive{|v|}
      @notifier.should be_notified
    end

    it "should notify when being closed" do
      @notifier.should_not be_notified
      @push.close
      @notifier.should be_notified
    end
  end

end
