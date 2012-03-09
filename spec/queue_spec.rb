require "spec_helper"
include Agent::Transport

describe Agent::Transport::Queue do
  include Agent::Transport

  it "should support synchronous, unbuffered communication" do
    lambda { Agent::Transport::Queue.new("spec") }.should_not raise_error

    q = Agent::Transport::Queue.new("spec")
    q.max.should == 1
    q.async?.should be_false

    lambda { q.send("hello") }.should_not raise_error
    lambda { q.send("hello", true) }.should raise_error(ThreadError, "buffer full")

    q.receive.should == "hello"
    lambda { q.receive(true) }.should raise_error(ThreadError, "buffer empty")
  end

  it "should support asynchronous, buffered communication" do
    lambda { Agent::Transport::Queue.new("spec", 2) }.should_not raise_error

    q = Agent::Transport::Queue.new("spec", 2)
    q.max.should == 2
    q.async?.should be_true

    lambda { q.send("hello 1") }.should_not raise_error
    lambda { q.send("hello 2", true) }.should_not raise_error(ThreadError, "buffer full")
    lambda { q.send("hello 3", true) }.should raise_error(ThreadError, "buffer full")

    q.receive.should == "hello 1"
    q.receive.should == "hello 2"
    lambda { q.receive(true) }.should raise_error(ThreadError, "buffer empty")
  end

  it "should persist data between queue objects" do
    q = Agent::Transport::Queue.new("spec")
    q.send "hello"

    q = Agent::Transport::Queue.new("spec")
    q.receive.should == "hello"
  end

   it "should clear registry on close" do
     q = Agent::Transport::Queue.new("spec")
     q.send "hello"
     q.close

     q = Agent::Transport::Queue.new("spec")
     lambda { q.receive(true) }.should raise_error(ThreadError, "buffer empty")
   end

end
