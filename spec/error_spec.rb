require "spec_helper"

describe Agent::Error do
  before do
    @error = Agent::Error.new("msg")
  end

  it "should create an error" do
    expect(@error.to_s).to eq("msg")
  end

  it "should match the error's message" do
    expect(@error).to be_message("msg")
  end
end
