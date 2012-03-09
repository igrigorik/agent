require 'lib/agent'

# First, we declare a new Ruby struct, which will encapsulate several arguments, and then
# declare a clientRequests channel, which will carry our Request struct. Nothing unusual,
# except that we also set the size of our channel to two – we’ll see why in a
# second.

Request = Struct.new(:args, :resultChan)
clientRequests = channel!(:type => Request, :size => 2)

# Now, we create a new worker block, which takes in a “reqs” object, calls receive on it
# (hint, req’s is a Channel!), sleeps for a bit, and then sends back a timestamped
# result. With the help of some Ruby syntax sugar, we then start two workers by passing
# this block to our go function.

worker = Proc.new do |reqs|
  loop do
    req = reqs.receive
    sleep 1.0
    req.resultChan << [Time.now, req.args + 1].join(' : ')
  end
end

# start two workers
go!(clientRequests, &worker)
go!(clientRequests, &worker)

# The rest is simple, we create two distinct requests, which carry a number and a reply
# channel, and pass them to our clientRequests pipe, on which our workers are waiting.
# Once dispatched, we simply call receive and wait for the results!

req1 = Request.new(1, channel!(:type => String))
req2 = Request.new(2, channel!(:type => String))

clientRequests << req1
clientRequests << req2

# retrieve results
puts req1.resultChan.receive  # => 2010-11-28 23:31:08 -0500 : 2
puts req2.resultChan.receive  # => 2010-11-28 23:31:08 -0500 : 3

# Notice something interesting? Both results came back with the same timestamp! Our
# clientRequests channel allowed for up to two messages in the pipe, which our workers
# immediately received, executed, and returned the results.  Once again, not a thread
# or a mutex in sight.