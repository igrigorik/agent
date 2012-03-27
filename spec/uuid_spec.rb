require "spec_helper"

describe Agent::UUID do
  it "should generate a uuid" do
    Agent::UUID.generate.should match(/^[0-9a-f]{8}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{12}$/)
  end

  it "should generate unique IDs across the BLOCK_SIZE boundary" do
    upper_bound = Agent::UUID::BLOCK_SIZE * 2 + 10
    uuids = (1..upper_bound).map{ Agent::UUID.generate }
    uuids.size.should == uuids.uniq.size
  end
end
