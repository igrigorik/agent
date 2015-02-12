require "spec_helper"

describe Agent::Queues do
  after do
    Agent::Queues.clear
  end

  it "should register queues" do
    Agent::Queues.register("foo", String, 10)
    expect(Agent::Queues["foo"]).to be_a(Agent::Queue)
    expect(Agent::Queues["foo"].type).to eq(String)
    expect(Agent::Queues["foo"].max).to eq(10)
  end

  it "should delete queues" do
    Agent::Queues.register("foo", String, 10)
    Agent::Queues.delete("foo")
    expect(Agent::Queues["foo"]).to be_nil
  end

  it "should remove all queues queues" do
    Agent::Queues.register("foo", String, 10)
    Agent::Queues.register("bar", String, 10)
    Agent::Queues.clear
    expect(Agent::Queues["foo"]).to be_nil
    expect(Agent::Queues["bar"]).to be_nil
  end
end
