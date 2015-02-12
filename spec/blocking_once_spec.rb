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

    expect(r.size).to eq(1)
    expect(r.first).to eq(1)
  end

  it "should only execute the first block passed to it" do
    r = []

    @blocking_once.perform do
      r << 1
    end

    @blocking_once.perform do
      r << 2
    end

    expect(r.size).to eq(1)
    expect(r.first).to eq(1)
  end

  it "should return the value returned from the block" do
    value, error = @blocking_once.perform do
      1
    end

    expect(value).to eq(1)
  end

  it "should return nil for value and an error if it has already been used" do
    value, error = @blocking_once.perform{ 1 }
    expect(value).to eq(1)
    expect(error).to be_nil

    value, error = @blocking_once.perform{ 2 }
    expect(value).to be_nil
    expect(error).not_to be_nil
    expect(error).to be_message("already performed")
  end

  it "should roll back and allow the block to be executed again" do
    s = Time.now.to_f

    finished_channel = channel!(TrueClass, 2)

    go! do
      @blocking_once.perform do
        sleep 0.1
        finished_channel.send(true)
        raise Agent::Errors::Rollback
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

    # Three sleeps at 0.1 == 0.3, so if it's less than 0.3...
    expect(Time.now.to_f - s).to be < 0.3
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
      @blocking_once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    go! do
      mutex.synchronize{ waiting_channel.send(true); condition.wait(mutex) }
      @blocking_once.perform{ sleep 0.1; r << 1 }
      finished_channel.send(true)
    end

    # wait for both the goroutines to be waiting
    2.times{ waiting_channel.receive }

    mutex.synchronize{ condition.broadcast }

    # wait for the finished channel to be completed
    2.times{ finished_channel.receive }

    expect(r.size).to eq(1)
    # Onlt the first sleep should be performed, so things should quickly
    expect(Time.now.to_f - s).to be_within(0.05).of(0.15)

    waiting_channel.close
    finished_channel.close
  end

end
