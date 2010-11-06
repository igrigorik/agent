require 'rspec'
require 'lib/go'

describe Go::Channel do
  # http://golang.org/doc/go_spec.html#Channel_types

  it "should respond to close"
  it "should respond to closed?"

  context "direction" do
    # A channel provides a mechanism for two concurrently executing functions to
    # synchronize execution and communicate by passing a value of a specified element
    # type. The value of an uninitialized channel is nil.

    it "should support send only"
    it "should support recieve only"
    it "should support bi-directional communication"
  end

  context "capacity" do
    # The capacity, in number of elements, sets the size of the buffer in the channel.
    # If the capacity is greater than zero, the channel is asynchronous: provided the
    # buffer is not full, sends can succeed without blocking. If the capacity is zero
    # or absent, the communication succeeds only when both a sender and receiver are ready.

    it "should default to synchronous communication"
    it "should support asynchronous communication with buffered capacity"
  end

  context "typed" do
    # Maybe?
    it "should create a typed channel"
    it "should reject messages of invalid type"
  end

  context "channels of channels" do
    # One of the most important properties of Go is that a channel is a first-class
    # value that can be allocated and passed around like any other. A common use of
    # this property is to implement safe, parallel demultiplexing.
    # - http://golang.org/doc/effective_go.html#chan_of_chan

    it "should be a first class, serializable value"
    it "should be able to pass as a value on a different channel"
  end

end