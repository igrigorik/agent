require "spec_helper"

describe Agent::WaitGroup do

  before do
    @wait_group = Agent::WaitGroup.new
  end

  it "should allow adding" do
    @wait_group.add(1)
  end

  it "should allow adding negative numbers" do
    @wait_group.add(2)
    @wait_group.add(-1)
  end

  it "should decrement the cound when WaitGroup#done is called" do
    @wait_group.add(1)
    expect(@wait_group.count).to eq(1)
    @wait_group.done
    expect(@wait_group.count).to eq(0)
  end

  it "should error when the count becomes negative via WaitGroup#add" do
    expect{ @wait_group.add(-1) }.to raise_error(Agent::Errors::NegativeWaitGroupCount)
  end

  it "should error when the count becomes negative via WaitGroup#done" do
    expect{ @wait_group.done }.to raise_error(Agent::Errors::NegativeWaitGroupCount)
  end

  it "should allow waiting on a wait_group and should signal when it is done" do
    @wait_group.add(1)

    go!{ sleep 0.2; @wait_group.done }

    t = Time.now

    @wait_group.wait

    expect(Time.now - t).to be_within(0.01).of(0.2)
  end

end
