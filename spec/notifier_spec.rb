require "spec_helper"

describe Agent::Notifier do
  before do
    @notifier = Agent::Notifier.new
  end

  it "should notify using a payload" do
    @notifier.notify(1)
    @notifier.payload.should == 1
  end

  it "should acknowledge notification" do
    @notifier.should_not be_notified
    @notifier.notify(1)
    @notifier.should be_notified
  end

  it "should only notify once" do
    @notifier.notify(1)
    @notifier.notify(2)
    @notifier.payload.should == 1
  end

  it "should return nil when notified for the first time" do
    @notifier.notify(1).should be_nil
  end

  it "should return an error when notified more than once" do
    @notifier.notify(1)
    @notifier.notify(2).should be_message("already notified")
  end

  it "should allow waiting on a notification and should signal when it is notified" do
    ack = channel!(Integer)
    go!{ @notifier.wait; ack.send(@notifier.payload) }
    sleep 0.1 # make sure the notifier in the goroutine is waiting
    @notifier.notify(1)
    payload, _ = ack.receive
    payload.should == 1
  end
end