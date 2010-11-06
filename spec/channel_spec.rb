require 'helper'

describe Go::Channel do
  # http://golang.org/doc/go_spec.html#Channel_types

  include Go
  let(:c) { Channel.new(:type => String) }

  it "should respond to close" do
    lambda { c.close }.should_not raise_error
    c.closed?.should be_true
  end

  it "should respond to closed?" do
    c.closed?.should be_false
    c.close
    c.closed?.should be_true
  end

  it "should be a first class, serializable value" do
    lambda { Marshal.dump(c) }.should_not raise_error
    lambda { Marshal.load(Marshal.dump(c)).is_a? Channel }.should_not raise_error
  end

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only" do
      c = Channel.new(:direction => :send, :type => String)

      lambda { c << "hello"   }.should_not raise_error
      lambda { c.push "hello" }.should_not raise_error
      lambda { c.send "hello" }.should_not raise_error

      lambda { c.pop }.should raise_error Channel::InvalidDirection
      lambda { c.receive }.should raise_error Channel::InvalidDirection
    end

    it "should support receive only" do
      c = Channel.new(:direction => :receive, :type => String)

      lambda { c << "hello"   }.should raise_error Channel::InvalidDirection
      lambda { c.push "hello" }.should raise_error Channel::InvalidDirection
      lambda { c.send "hello" }.should raise_error Channel::InvalidDirection

      lambda { c.pop }.should_not raise_error
      lambda { c.receive }.should_not raise_error
    end

    it "should default to bi-directional communication" do
      lambda { c.send "hello" }.should_not raise_error
      lambda { c.receive }.should_not raise_error
    end
  end

  context "typed" do
    it "should create a typed channel" do
      lambda { Channel.new }.should raise_error Channel::Untyped
      lambda { Channel.new(:type => Integer) }.should_not raise_error
    end

    it "should reject messages of invalid type" do
      lambda { c.send 1 }.should raise_error(Channel::InvalidType)
      lambda { c.send "hello" }.should_not raise_error
    end
  end

  context "transport" do
    context "channels of channels" do
      # One of the most important properties of Go is that a channel is a first-class
      # value that can be allocated and passed around like any other. A common use of
      # this property is to implement safe, parallel demultiplexing.
      # - http://golang.org/doc/effective_go.html#chan_of_chan

      it "should be able to pass as a value on a different channel"
    end

    context "capacity" do
      # The capacity, in number of elements, sets the size of the buffer in the channel.
      # If the capacity is greater than zero, the channel is asynchronous: provided the
      # buffer is not full, sends can succeed without blocking. If the capacity is zero
      # or absent, the communication succeeds only when both a sender and receiver are ready.

      it "should default to synchronous communication"
      it "should support asynchronous communication with buffered capacity"
    end
  end

end
