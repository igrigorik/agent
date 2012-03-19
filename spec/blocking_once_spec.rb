require "spec_helper"

describe Agent::BlockingOnce do

  before do
    @blocking_once = Agent::BlockingOnce.new
  end

  it "should execute the block passed to it" do
    r = []

    @blocking_once.perform do
      r << 1
    end

    r.size.should == 1
    r.first.should == 1
  end

  it "should only execute the first block passed to it" do
    r = []

    @blocking_once.perform do
      r << 1
    end

    @blocking_once.perform do
      r << 2
    end

    r.size.should == 1
    r.first.should == 1
  end

  it "should return the value returned from the block" do
    value, error = @blocking_once.perform do
      1
    end

    value.should == 1
  end

  it "should return nil for value and an error if it has already been used" do
    value, error = @blocking_once.perform{ 1 }
    value.should == 1
    error.should be_nil

    value, error = @blocking_once.perform{ 2 }
    value.should be_nil
    error.should_not be_nil
    error.should be_message("already performed")
  end

  it "should roll back and allow the block to be executed again" do
    s = Time.now.to_f

    finished_channel = channel!(:type => TrueClass, :size => 2)

    go! do
      @blocking_once.perform do
        sleep 0.1
        finished_channel.send(true)
        raise Agent::BlockingOnce::Rollback
      end
    end

    sleep 0.1 # make sure the first @blocking_once calls #perform

    go! do
      @blocking_once.perform do
        sleep 0.1
        finished_channel.send(true)
      end
    end

    2.times { finished_channel.receive }

    finished_channel.close

    (Time.now.to_f - s).should be_within(0.05).of(0.2)
  end

  it "should have minimal contention between threads when they contend for position" do
    r, s = [], Time.now.to_f

    # Using condition variables to maximize potential contention
    monitor   = Monitor.new
    condition = monitor.new_cond

    waiting_channel  = channel!(:type => TrueClass, :size => 2)
    finished_channel = channel!(:type => TrueClass, :size => 2)

    go! do
      monitor.synchronize{ waiting_channel.send(true); condition.wait }
      @blocking_once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    go! do
      monitor.synchronize{ waiting_channel.send(true); condition.wait }
      @blocking_once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    # wait for both the goroutines to be waiting
    2.times{ waiting_channel.receive }

    monitor.synchronize{ condition.broadcast }

    # wait for the finished channel to be completed
    2.times{ finished_channel.receive }

    r.size.should == 1
    # Onlt the first sleep should be performed, so things should quickly
    (Time.now.to_f - s).should be_within(0.05).of(0.15)

    waiting_channel.close
    finished_channel.close
  end

end
