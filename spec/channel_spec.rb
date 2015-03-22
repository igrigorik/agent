require "spec_helper"

describe Agent::Channel do

  context "naming" do
    it "should not be required" do
      c = nil
      expect { c = channel!(String) }.not_to raise_error
      c.close
    end

    it "be able to be set" do
      c = channel!(String, :name => "gibberish")
      expect(c.name).to eq("gibberish")
      c.close
    end
  end

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only" do
      c = channel!(String, 3, :direction => :send)

      expect { c << "hello"   }.not_to raise_error
      expect { c.push "hello" }.not_to raise_error
      expect { c.send "hello" }.not_to raise_error

      expect(c.direction).to eq(:send)

      expect { c.pop }.to raise_error Agent::Errors::InvalidDirection
      expect { c.receive }.to raise_error Agent::Errors::InvalidDirection

      c.close
    end

    it "should support receive only" do
      c = channel!(String, :direction => :receive)

      expect { c << "hello"   }.to raise_error Agent::Errors::InvalidDirection
      expect { c.push "hello" }.to raise_error Agent::Errors::InvalidDirection
      expect { c.send "hello" }.to raise_error Agent::Errors::InvalidDirection

      expect(c.direction).to eq(:receive)

      # timeout blocking receive calls
      timed_out = false
      select! do |s|
        s.case(c, :receive)
        s.timeout(0.1){ timed_out = true }
      end
      expect(timed_out).to eq(true)
      c.close
    end

    it "should default to bi-directional communication" do
      c = channel!(String, 1)
      expect { c.send "hello" }.not_to raise_error
      expect { c.receive }.not_to raise_error

      expect(c.direction).to eq(:bidirectional)
    end

    it "should be able to be dup'd as a uni-directional channel" do
      c = channel!(String, 1)

      send_only = c.as_send_only
      expect(send_only.direction).to eq(:send)

      receive_only = c.as_receive_only
      expect(receive_only.direction).to eq(:receive)

      send_only.send("nifty")
      expect(receive_only.receive[0]).to eq("nifty")
    end
  end

  context "closing" do
    before do
      @c = channel!(Integer, 3)
    end

    it "not raise an error the first time it is called" do
      expect { @c.close }.not_to raise_error
      expect(@c).to be_closed
    end

    it "should raise an error the second time it is called" do
      @c.close
      expect { @c.close }.to raise_error(Agent::Errors::ChannelClosed)
    end

    it "should respond to closed?" do
      expect(@c).not_to be_closed
      @c.close
      expect(@c).to be_closed
    end

    it "should return that a receive was a failure when a channel is closed while being read from" do
      go!{ sleep 0.01; @c.close }
      _, ok = @c.receive
      expect(ok).to eq(false)
    end

    it "should raise an error when sending to a channel that has already been closed" do
      @c.close
      expect { @c.send("a") }.to raise_error(Agent::Errors::ChannelClosed)
    end

    it "should return [nil, false] when receiving from a channel that has already been closed" do
      @c.close
      expect(@c.receive).to eq([nil, false])
    end

    it "should return buffered items from a closed channel" do
      @c << 1
      @c << 2
      @c.close
      expect(@c.receive).to eq([1, true])
      expect(@c.receive).to eq([2, true])
      expect(@c.receive).to eq([nil, false])
      expect(@c.receive).to eq([nil, false])
    end
  end

  context "deadlock" do
    before do
      @c = channel!(String)
    end

    it "should deadlock on single thread", :vm => :ruby do
      expect { @c.receive }.to raise_error
    end

    it "should not deadlock with multiple threads" do
      go!{ sleep(0.1); @c.push "hi" }
      expect { @c.receive }.not_to raise_error
    end
  end

  context "typed" do
    it "should create a typed channel" do
      expect { channel! }.to raise_error Agent::Errors::Untyped
      c = nil
      expect { c = channel!(Integer) }.not_to raise_error
      c.close
    end

    it "should reject messages of invalid type" do
      c = channel!(String)
      go!{ c.receive }
      expect { c.send 1 }.to raise_error(Agent::Errors::InvalidType)
      expect { c.send "hello" }.not_to raise_error
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
      expect(c.receive[0]).to eq("hello")

      expect(Time.now - n).to be_within(0.05).of(0.15)
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

      expect(c.receive[0]).to eq("hello 1")
      expect(c.receive[0]).to eq("hello 2")
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
      expect { Marshal.dump(@c) }.not_to raise_error
      expect { Marshal.load(Marshal.dump(@c)).is_a?(Agent::Channel) }.not_to raise_error
    end

    it "should be able to pass as a value on a different channel" do
      @c.send "hello"

      cm = Marshal.load(Marshal.dump(@c))
      expect(cm.receive[0]).to eq("hello")
    end
  end

  context "marshaling" do
    it "marshals data by default" do
      c = channel!(String, 1)
      string = "foo"
      c.send(string)
      string_copy = c.receive[0]
      expect(string_copy).to eq(string)
      expect(string_copy.object_id).not_to eq(string.object_id)
    end

    it "skips marshaling when configured to" do
      c = channel!(String, 1, :skip_marshal => true)
      string = "foo"
      c.send(string)
      expect(c.receive[0].object_id).to eq(string.object_id)
    end

    it "skips marshaling for channels by default" do
      c = channel!(Agent::Channel, 1)
      c.send(c)
      expect(c.receive[0].object_id).to eq(c.object_id)
    end
  end
end

