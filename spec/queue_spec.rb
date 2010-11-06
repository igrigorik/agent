require 'helper'

describe Go::Transport::Queue do
  include Go::Transport

  it "should support synchronous, unbuffered communication" do
    lambda { Queue.new }.should_not raise_error

    q = Queue.new
    q.max.should == 1
    q.async?.should be_false

    lambda { q.send("hello") }.should_not raise_error
    lambda { q.send("hello", true) }.should raise_error(ThreadError, "buffer full")

    q.receive.should == "hello"
    lambda { q.receive(true) }.should raise_error(ThreadError, "buffer empty")
  end

  it "should support asynchronous, buffered communication" do
    lambda { Queue.new(2) }.should_not raise_error

    q = Queue.new(2)
    q.max.should == 2
    q.async?.should be_true

    lambda { q.send("hello 1") }.should_not raise_error
    lambda { q.send("hello 2", true) }.should_not raise_error(ThreadError, "buffer full")
    lambda { q.send("hello 3", true) }.should raise_error(ThreadError, "buffer full")

    q.receive.should == "hello 1"
    q.receive.should == "hello 2"
    lambda { q.receive(true) }.should raise_error(ThreadError, "buffer empty")
  end

end
