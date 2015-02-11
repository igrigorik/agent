require "spec_helper"

describe Agent::Channel do

  context "naming" do
    it "should not be required" do
      c = nil
      lambda { c = channel!(String) }.should_not raise_error
      c.close
    end

    it "be able to be set" do
      c = channel!(String, :name => "gibberish")
      c.name.should == "gibberish"
      c.close
    end
  end

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only" do
      c = channel!(String, 3, :direction => :send)

      lambda { c << "hello"   }.should_not raise_error
      lambda { c.push "hello" }.should_not raise_error
      lambda { c.send "hello" }.should_not raise_error

      c.direction.should == :send

      lambda { c.pop }.should raise_error Agent::Errors::InvalidDirection
      lambda { c.receive }.should raise_error Agent::Errors::InvalidDirection

      c.close
    end

    it "should support receive only" do
      c = channel!(String, :direction => :receive)

      lambda { c << "hello"   }.should raise_error Agent::Errors::InvalidDirection
      lambda { c.push "hello" }.should raise_error Agent::Errors::InvalidDirection
      lambda { c.send "hello" }.should raise_error Agent::Errors::InvalidDirection

      c.direction.should == :receive

      # timeout blocking receive calls
      timed_out = false
      select! do |s|
        s.case(c, :receive)
        s.timeout(0.1){ timed_out = true }
      end
      timed_out.should == true
      c.close
    end

    it "should default to bi-directional communication" do
      c = channel!(String, 1)
      lambda { c.send "hello" }.should_not raise_error
      lambda { c.receive }.should_not raise_error

      c.direction.should == :bidirectional
    end

    it "should be able to be dup'd as a uni-directional channel" do
      c = channel!(String, 1)

      send_only = c.as_send_only
      send_only.direction.should == :send

      receive_only = c.as_receive_only
      receive_only.direction.should == :receive

      send_only.send("nifty")
      receive_only.receive[0].should == "nifty"
    end
  end

  context "closing" do
    before do
      @c = channel!(String)
    end

    it "not raise an error the first time it is called" do
      lambda { @c.close }.should_not raise_error
      @c.closed?.should be_true
    end

    it "should raise an error the second time it is called" do
      @c.close
      lambda { @c.close }.should raise_error(Agent::Errors::ChannelClosed)
    end

    it "should respond to closed?" do
      @c.closed?.should be_false
      @c.close
      @c.closed?.should be_true
    end

    it "should return that a receive was a failure when a channel is closed while being read from" do
      go!{ sleep 0.01; @c.close }
      _, ok = @c.receive
      ok.should be_false
    end

    it "should raise an error when sending to a channel that has already been closed" do
      @c.close
      lambda { @c.send("a") }.should raise_error(Agent::Errors::ChannelClosed)
    end

    it "should return [nil, false] when receiving from a channel that has already been closed" do
      @c.close
      @c.receive.should == [nil, false]
    end
  end

  context "deadlock" do
    before do
      @c = channel!(String)
    end

    it "should deadlock on single thread", :vm => :ruby do
      lambda { @c.receive }.should raise_error
    end

    it "should not deadlock with multiple threads" do
      go!{ sleep(0.1); @c.push "hi" }
      lambda { @c.receive }.should_not raise_error
    end
  end

  context "typed" do
    it "should create a typed channel" do
      lambda { channel! }.should raise_error Agent::Errors::Untyped
      c = nil
      lambda { c = channel!(Integer) }.should_not raise_error
      c.close
    end

    it "should reject messages of invalid type" do
      c = channel!(String)
      go!{ c.receive }
      lambda { c.send 1 }.should raise_error(Agent::Errors::InvalidType)
      lambda { c.send "hello" }.should_not raise_error
      c.close
    end
  end

  context "buffering" do
    # The capacity, in number of elements, sets the size of the buffer in the channel.
    # If the capacity is greater than zero, the channel is buffered: provided the
    # buffer is not full, sends can succeed without blocking. If the capacity is zero
    # or absent, the communication succeeds only when both a sender and receiver are ready.

    it "should default to unbuffered" do
      n = Time.now
      c = channel!(String)

      go!{ sleep(0.15); c.send("hello") }
      c.receive[0].should == "hello"

      (Time.now - n).should be_within(0.05).of(0.15)
    end

    it "should support buffered" do
      c = channel!(String, 2)
      r = []

      c.send "hello 1"
      c.send "hello 2"

      select! do |s|
        s.case(c, :send, "hello 3")
        s.timeout(0.1)
      end

      c.receive[0].should == "hello 1"
      c.receive[0].should == "hello 2"
      select! do |s|
        s.case(c, :receive){|v| r.push(v) }
        s.timeout(0.1)
      end

      c.close
    end
  end

  context "channels of channels" do
    before do
      @c = channel!(String, 1)
    end

    after do
      @c.close unless @c.closed?
    end

    # One of the most important properties of Go is that a channel is a first-class
    # value that can be allocated and passed around like any other. A common use of
    # this property is to implement safe, parallel demultiplexing.
    # - http://golang.org/doc/effective_go.html#chan_of_chan

    it "should be a first class, serializable value" do
      lambda { Marshal.dump(@c) }.should_not raise_error
      lambda { Marshal.load(Marshal.dump(@c)).is_a?(Agent::Channel) }.should_not raise_error
    end

    it "should be able to pass as a value on a different channel" do
      @c.send "hello"

      cm = Marshal.load(Marshal.dump(@c))
      cm.receive[0].should == "hello"
    end
  end

  context "marshaling" do
    it "marshals data by default" do
      c = channel!(String, 1)
      string = "foo"
      c.send(string)
      string_copy = c.receive[0]
      string_copy.should == string
      string_copy.object_id.should_not == string.object_id
    end

    it "skips marshaling when configured to" do
      c = channel!(String, 1, :skip_marshal => true)
      string = "foo"
      c.send(string)
      c.receive[0].object_id.should == string.object_id
    end

    it "skips marshaling for channels by default" do
      c = channel!(Agent::Channel, 1)
      c.send(c)
      c.receive[0].object_id.should == c.object_id
    end
  end
end

