require "spec_helper"

describe Agent::UUID do
  it "should generate a uuid" do
    Agent::UUID.generate.should match(/^[0-9a-f]{8}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{4}_[0-9a-f]{12}$/)
  end
end
