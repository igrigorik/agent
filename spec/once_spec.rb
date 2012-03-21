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

    r.size.should == 1
    r.first.should == 1
  end

  it "should only execute the first block passed to it" do
    r = []

    @once.perform do
      r << 1
    end

    @once.perform do
      r << 2
    end

    r.size.should == 1
    r.first.should == 1
  end

  it "should return the value returned from the block" do
    value, error = @once.perform do
      1
    end

    value.should == 1
  end

  it "should return nil for value and an error if it has already been used" do
    value, error = @once.perform{ 1 }
    value.should == 1
    error.should be_nil

    value, error = @once.perform{ 2 }
    value.should be_nil
    error.should_not be_nil
    error.should be_message("already performed")
  end

  it "should have minimal contention between threads when they contend for position" do
    r, s = [], Time.now.to_f

    # Using condition variables to maximize potential contention
    mutex     = Mutex.new
    condition = ConditionVariable.new

    waiting_channel  = channel!(:type => TrueClass, :size => 2)
    finished_channel = channel!(:type => TrueClass, :size => 2)

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

    r.size.should == 1
    # Onlt the first sleep should be performed, so things should quickly
    (Time.now.to_f - s).should be_within(0.05).of(0.15)

    waiting_channel.close
    finished_channel.close
  end
end
