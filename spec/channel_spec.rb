require "spec_helper"

describe Agent::Channel do
  before do
    @c = channel!(:type => String)
  end

  after do
    @c.close unless @c.closed?
  end

  context "naming" do
    it "should not be required" do
      c = nil
      lambda { c = channel!(:type => String) }.should_not raise_error
      c.close
    end

    it "be able to be set" do
      c = channel!(:type => String, :name => "gibberish")
      c.name.should == "gibberish"
      c.close
    end
  end

  context "closing" do
    it "not raise an error the first time it is called" do
      lambda { @c.close }.should_not raise_error
      @c.closed?.should be_true
    end

    it "should raise an error the second time it is called" do
      @c.close
      lambda { @c.close }.should raise_error(Agent::Channel::ChannelClosed)
    end

    it "should respond to closed?" do
      @c.closed?.should be_false
      @c.close
      @c.closed?.should be_true
    end
  end

  context "deadlock" do
    it "should deadlock on single thread", :vm => :ruby do
      lambda { @c.receive }.should raise_error
    end

    it "should not deadlock with multiple threads" do
      Thread.new { sleep(0.1); @c.push "hi" }
      lambda { @c.receive }.should_not raise_error
    end
  end

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only" do
      c = channel!(:direction => :send, :type => String, :size => 3)

      lambda { c << "hello"   }.should_not raise_error
      lambda { c.push "hello" }.should_not raise_error
      lambda { c.send "hello" }.should_not raise_error

      lambda { c.pop }.should raise_error Agent::Channel::InvalidDirection
      lambda { c.receive }.should raise_error Agent::Channel::InvalidDirection

      c.close
    end

    it "should support receive only" do
      c = channel!(:direction => :receive, :type => String)

      lambda { c << "hello"   }.should raise_error Agent::Channel::InvalidDirection
      lambda { c.push "hello" }.should raise_error Agent::Channel::InvalidDirection
      lambda { c.send "hello" }.should raise_error Agent::Channel::InvalidDirection

      # timeout blocking receive calls
      timed_out = false
      select! do |s|
        s.case(c, :receive){}
        s.timeout(0.1){ timed_out = true }
      end
      timed_out.should == true
      c.close
    end

    it "should default to bi-directional communication" do
      lambda { @c.send "hello" }.should_not raise_error
      lambda { @c.receive }.should_not raise_error
    end
  end

  context "typed" do
    it "should create a typed channel" do
      lambda { channel!({}) }.should raise_error Agent::Channel::Untyped
      c = nil
      lambda { c = channel!(:type => Integer) }.should_not raise_error
      c.close
    end

    it "should reject messages of invalid type" do
      lambda { @c.send 1 }.should raise_error(Agent::Channel::InvalidType)
      lambda { @c.send "hello" }.should_not raise_error
    end
  end

  context "queue" do
    context "channels of channels" do
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

    context "capacity" do
      # The capacity, in number of elements, sets the size of the buffer in the channel.
      # If the capacity is greater than zero, the channel is asynchronous: provided the
      # buffer is not full, sends can succeed without blocking. If the capacity is zero
      # or absent, the communication succeeds only when both a sender and receiver are ready.

      it "should default to synchronous communication" do
        @c.send "hello"
        @c.receive[0].should == "hello"
        select! do |s|
          s.case(@c, :receive){}
          s.timeout(0.1){}
        end
      end

      it "should support asynchronous communication with buffered capacity" do
        c = channel!(:type => String, :size => 2)

        c.send "hello 1"
        c.send "hello 2"

        select! do |s|
          s.case(@c, :send, "hello 3"){}
          s.timeout(0.1){}
        end

        c.receive[0].should == "hello 1"
        c.receive[0].should == "hello 2"
        select! do |s|
          s.case(@c, :receive){}
          s.timeout(0.1){}
        end

        c.close
      end
    end
  end

end
