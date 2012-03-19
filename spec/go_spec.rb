require "spec_helper"

describe "Agent.go!" do
  it "should launch a 'goroutine' that is actually a thread" do
    Agent.go!{}.should be_a(Thread)
  end

  it "should pass into the thread any arguments passed to it" do
    b = nil
    Agent.go!(1){|a| b = a }.join
    b.should == 1
  end

  it "should raise an error if no block is passed" do
    lambda{ Agent.go! }.should raise_error(Agent::BlockMissing)
  end
end
