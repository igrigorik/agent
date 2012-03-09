require "spec_helper"

describe Agent::Error do
  before do
    @error = Agent::Error.new("msg")
  end

  it "should create an error" do
    @error.to_s.should == "msg"
  end

  it "should match the error's message" do
    @error.should be_message("msg")
  end
end
