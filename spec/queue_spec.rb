require "spec_helper"

describe Agent::Queue do
  before do
    @queue = Agent::Queue.new("name", 2)
  end

  it "should be able to be pushed to" do
    lambda{ @queue.push(Agent::Push.new("1")) }.should_not raise_error
  end

  it "should mark the push as sent" do
    push = Agent::Push.new("1")
    @queue.push(push)
    push.wait
    push.sent?.should == true
  end

  context "when there are elements in the queue" do
    before do
      push = Agent::Push.new("1")
      @queue.push(push)
      push.wait
    end

    it "should be able to be popped from" do
      pop = Agent::Pop.new
      @queue.pop(pop)
      pop.wait
      pop.object.should == "1"
    end
  end
end
