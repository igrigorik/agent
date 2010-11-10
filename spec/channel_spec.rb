require "helper"

describe Agent::Channel do
  # http://golang.org/doc/go_spec.html#Channel_types

  include Agent
  let(:c) { Channel.new(:name => "spec", :type => String) }

  it "should have a name" do
    lambda { Channel.new(:type => String) }.should raise_error(Channel::NoName)
    c.name.should == "spec"
  end

  it "should respond to close" do
    lambda { c.close }.should_not raise_error
    c.closed?.should be_true
  end

  it "should respond to closed?" do
    c.closed?.should be_false
    c.close
    c.closed?.should be_true
  end

  context "deadlock" do
    it "should deadlock on single thread" do
      c = Channel.new(:name => "deadlock", :type => String)
      lambda { c.receive }.should raise_error
      c.close
    end

    it "should not deadlock with multiple threads" do
      c = Channel.new(:name => "deadlock", :type => String)
      Thread.new { sleep(0.1); c.push "hi" }
      lambda { c.receive }.should_not raise_error
      c.close
    end
  end

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only" do
      c = Channel.new(:name => "spec", :direction => :send, :type => String, :size => 3)

      lambda { c << "hello"   }.should_not raise_error
      lambda { c.push "hello" }.should_not raise_error
      lambda { c.send "hello" }.should_not raise_error

      lambda { c.pop }.should raise_error Channel::InvalidDirection
      lambda { c.receive }.should raise_error Channel::InvalidDirection

      c.close
    end

    it "should support receive only" do
      c = Channel.new(:name => "spec", :direction => :receive, :type => String)

      lambda { c << "hello"   }.should raise_error Channel::InvalidDirection
      lambda { c.push "hello" }.should raise_error Channel::InvalidDirection
      lambda { c.send "hello" }.should raise_error Channel::InvalidDirection

      # timeout blocking receive calls
      lambda { Timeout::timeout(0.1) { c.pop } }.should raise_error(Timeout::Error)
      lambda { Timeout::timeout(0.1) { c.receive } }.should raise_error(Timeout::Error)
    end

    it "should default to bi-directional communication" do
      lambda { c.send "hello" }.should_not raise_error
      lambda { c.receive }.should_not raise_error
    end
  end

  context "typed" do
    it "should create a typed channel" do
      lambda { Channel.new(:name => "spec") }.should raise_error Channel::Untyped
      lambda { Channel.new(:name => "spec", :type => Integer) }.should_not raise_error
    end

    it "should reject messages of invalid type" do
      lambda { c.send 1 }.should raise_error(Channel::InvalidType)
      lambda { c.send "hello" }.should_not raise_error
      c.receive
    end
  end

  context "transport" do
    it "should default to memory transport" do
      c.transport.should == Agent::Transport::Queue
    end

    context "channels of channels" do
      # One of the most important properties of Go is that a channel is a first-class
      # value that can be allocated and passed around like any other. A common use of
      # this property is to implement safe, parallel demultiplexing.
      # - http://golang.org/doc/effective_go.html#chan_of_chan

      it "should be a first class, serializable value" do
        lambda { Marshal.dump(c) }.should_not raise_error
        lambda { Marshal.load(Marshal.dump(c)).is_a? Channel }.should_not raise_error
      end

      it "should be able to pass as a value on a different channel" do
        c.send "hello"

        cm = Marshal.load(Marshal.dump(c))
        cm.receive.should == "hello"
      end
    end

    context "capacity" do
      # The capacity, in number of elements, sets the size of the buffer in the channel.
      # If the capacity is greater than zero, the channel is asynchronous: provided the
      # buffer is not full, sends can succeed without blocking. If the capacity is zero
      # or absent, the communication succeeds only when both a sender and receiver are ready.

      it "should default to synchronous communication" do
        c = Channel.new(:name => "buffered", :type => String)

        c.send "hello"
        c.receive.should == "hello"
        lambda { Timeout::timeout(0.1) { c.receive } }.should raise_error(Timeout::Error)

        c.close
      end

      it "should support asynchronous communication with buffered capacity" do
        c = Channel.new(:name => "buffered", :type => String, :size => 2)

        c.send "hello 1"
        c.send "hello 2"
        lambda { Timeout::timeout(0.1) { c.send "hello 3" } }.should raise_error(Timeout::Error)

        c.receive.should == "hello 1"
        c.receive.should == "hello 2"
        lambda { Timeout::timeout(0.1) { c.receive } }.should raise_error(Timeout::Error)

        c.close
      end
    end
  end

end
