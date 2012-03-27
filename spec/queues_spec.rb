require "spec_helper"

describe Agent::Queues do
  after do
    Agent::Queues.clear
  end

  it "should register queues" do
    Agent::Queues.register("foo", String, 10)
    Agent::Queues["foo"].should be_a(Agent::Queue)
    Agent::Queues["foo"].type.should == String
    Agent::Queues["foo"].max.should == 10
  end

  it "should delete queues" do
    Agent::Queues.register("foo", String, 10)
    Agent::Queues.delete("foo")
    Agent::Queues["foo"].should be_nil
  end

  it "should remove all queues queues" do
    Agent::Queues.register("foo", String, 10)
    Agent::Queues.register("bar", String, 10)
    Agent::Queues.clear
    Agent::Queues["foo"].should be_nil
    Agent::Queues["bar"].should be_nil
  end
end
