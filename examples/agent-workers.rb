require 'lib/agent'

Request = Struct.new(:args, :resultChan)
clientRequests = Agent::Channel.new(name: :clientRequests, type: Request, size: 2)

worker = Proc.new do |reqs|
  loop do
    req = reqs.receive
    sleep 1.0
    req.resultChan << [Time.now, req.args + 1].join(' : ')
  end
end

# start two workers
go(clientRequests, &worker)
go(clientRequests, &worker)

# create and submit two requests
req1 = Request.new(1, Agent::Channel.new(:name => "resultChan-1", :type => String))
req2 = Request.new(2, Agent::Channel.new(:name => "resultChan-2", :type => String))

clientRequests << req1
clientRequests << req2

# retrieve results
puts req1.resultChan.receive  # => 2010-11-28 23:31:08 -0500 : 2
puts req2.resultChan.receive  # => 2010-11-28 23:31:08 -0500 : 3
