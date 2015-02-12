require "spec_helper"

describe Agent::Notifier do
  before do
    @notifier = Agent::Notifier.new
  end

  it "should notify using a payload" do
    @notifier.notify(1)
    expect(@notifier.payload).to eq(1)
  end

  it "should acknowledge notification" do
    expect(@notifier).not_to be_notified
    @notifier.notify(1)
    expect(@notifier).to be_notified
  end

  it "should only notify once" do
    @notifier.notify(1)
    @notifier.notify(2)
    expect(@notifier.payload).to eq(1)
  end

  it "should return nil when notified for the first time" do
    expect(@notifier.notify(1)).to be_nil
  end

  it "should return an error when notified more than once" do
    @notifier.notify(1)
    expect(@notifier.notify(2)).to be_message("already notified")
  end

  it "should allow waiting on a notification and should signal when it is notified" do
    ack = channel!(Integer)
    go!{ @notifier.wait; ack.send(@notifier.payload) }
    sleep 0.1 # make sure the notifier in the goroutine is waiting
    @notifier.notify(1)
    payload, _ = ack.receive
    expect(payload).to eq(1)
  end
end