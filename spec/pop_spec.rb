require "spec_helper"

describe Agent::Pop do

  context "in its basic operation" do
    before do
      @pop = Agent::Pop.new
      @ack = channel!(Time)
    end

    it "should close" do
      @pop.should_not be_closed
      @pop.close
      @pop.should be_closed
    end

    it "should run multiple times" do
      @pop.send{1}
      @pop.should be_received
      @pop.send{2}
      @pop.object.should == 2
    end

    it "should continue when received" do
      go!{ @pop.wait; @ack.send(Time.now) }
      sleep 0.2
      @pop.send{1}

      s, _ = @ack.receive

      (Time.now - s).should be_within(0.01).of(0)
    end

    it "should continue when closed" do
      go!{ @pop.wait; @ack.send(Time.now) }
      sleep 0.2
      @pop.close

      s, _ = @ack.receive

      (Time.now - s).should be_within(0.01).of(0)
    end

    it "should be able to be gracefully rolled back" do
      @pop.should_not be_received
      @pop.send{ raise Agent::Errors::Rollback }
      @pop.should_not be_received
    end

    it "should continue when it was already closed" do
      @pop.close

      go!{ @pop.wait; @ack.send(Time.now) }

      sleep 0.2

      s, _ = @ack.receive

      (Time.now - s).should be_within(0.01).of(0.2)
    end
  end

  context "with a blocking_once" do
    before do
      @blocking_once = Agent::BlockingOnce.new
      @pop = Agent::Pop.new(:blocking_once => @blocking_once)
    end

    it "should only send only once" do
      @blocking_once.should_not be_performed
      @pop.send{1}
      @pop.should be_received
      @blocking_once.should be_performed
      @pop.object.should == 1

      @pop.send{2}
      @pop.object.should == 1

      lambda{@pop.send{raise "an error"} }.should_not raise_error
    end

    it "be able to be gracefully rolled back" do
      @blocking_once.should_not be_performed
      @pop.should_not be_received
      @pop.send{ raise Agent::Errors::Rollback }
      @blocking_once.should_not be_performed
      @pop.should_not be_received
    end

    it "should send only once even when it is closed" do
      @pop.close
      @blocking_once.should_not be_performed
      @pop.send{1}
      @pop.should be_received
      @blocking_once.should be_performed
      @pop.object.should == nil

      @pop.send{2}
      @pop.object.should == nil

      lambda{@pop.send{raise "an error"} }.should_not raise_error
    end
  end

  context "with a notifier" do
    before do
      @notifier = Agent::Notifier.new
      @pop = Agent::Pop.new(:notifier => @notifier)
    end

    it "should notify when being sent" do
      @notifier.should_not be_notified
      @pop.send{1}
      @notifier.should be_notified
    end

    it "should notify when being closed" do
      @notifier.should_not be_notified
      @pop.close
      @notifier.should be_notified
    end
  end

end
