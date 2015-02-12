require "spec_helper"

describe Agent::Once do

  before do
    @once = Agent::Once.new
  end

  it "should execute the block passed to it" do
    r = []

    @once.perform do
      r << 1
    end

    expect(r.size).to eq(1)
    expect(r.first).to eq(1)
  end

  it "should only execute the first block passed to it" do
    r = []

    @once.perform do
      r << 1
    end

    @once.perform do
      r << 2
    end

    expect(r.size).to eq(1)
    expect(r.first).to eq(1)
  end

  it "should return the value returned from the block" do
    value, error = @once.perform do
      1
    end

    expect(value).to eq(1)
  end

  it "should return nil for value and an error if it has already been used" do
    value, error = @once.perform{ 1 }
    expect(value).to eq(1)
    expect(error).to be_nil

    value, error = @once.perform{ 2 }
    expect(value).to be_nil
    expect(error).not_to be_nil
    expect(error).to be_message("already performed")
  end

  it "should have minimal contention between threads when they contend for position" do
    r, s = [], Time.now.to_f

    # Using condition variables to maximize potential contention
    mutex     = Mutex.new
    condition = ConditionVariable.new

    waiting_channel  = channel!(TrueClass, 2)
    finished_channel = channel!(TrueClass, 2)

    go! do
      mutex.synchronize{ waiting_channel.send(true); condition.wait(mutex) }
      @once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    go! do
      mutex.synchronize{ waiting_channel.send(true); condition.wait(mutex) }
      @once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    # wait for both the goroutines to be waiting
    2.times{ waiting_channel.receive }

    mutex.synchronize{ condition.broadcast }

    # wait for the finished channel to be completed
    2.times{ finished_channel.receive }

    expect(r.size).to eq(1)
    # Only the first sleep should be performed, so things should happen quickly
    expect(Time.now.to_f - s).to be_within(0.05).of(0.15)

    waiting_channel.close
    finished_channel.close
  end
end
