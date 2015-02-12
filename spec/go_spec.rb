require "spec_helper"

describe "Agent.go!" do
  it "should launch a 'goroutine' that is actually a thread" do
    expect(Agent.go!{}).to be_a(Thread)
  end

  it "should pass into the thread any arguments passed to it" do
    b = nil
    Agent.go!(1){|a| b = a }.join
    expect(b).to eq(1)
  end

  it "should raise an error if no block is passed" do
    expect{ Agent.go! }.to raise_error(Agent::Errors::BlockMissing)
  end
end
