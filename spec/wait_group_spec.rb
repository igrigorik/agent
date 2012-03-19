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
    @wait_group.count.should == 1
    @wait_group.done
    @wait_group.count.should == 0
  end

  it "should error when the count becomes negative via WaitGroup#add" do
    lambda{ @wait_group.add(-1) }.should raise_error(Agent::WaitGroup::NegativeWaitGroupCount)
  end

  it "should error when the count becomes negative via WaitGroup#done" do
    lambda{ @wait_group.done }.should raise_error(Agent::WaitGroup::NegativeWaitGroupCount)
  end

  it "should allow waiting on a wait_group and should signal when it is done" do
    @wait_group.add(1)

    go!{ sleep 0.2; @wait_group.done }

    t = Time.now

    @wait_group.wait

    (Time.now - t).should be_within(0.01).of(0.2)
  end

end
