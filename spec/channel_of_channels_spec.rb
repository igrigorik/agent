require "helper"

describe "Channel of Channels" do
  it "should be able to pass channels as first class citizens" do

    # each request will provide an argument, and get passed
    # a reference to the result accumulator
    Request = Struct.new(:args, :resultChan)

    # resultChan will accumulate answers
    resultChan = Go::Channel.new(name: :resultChan, type: Integer)

    # channel of user requests
    clientRequests = Go::Channel.new(name: :clientRequests, type: Request)

    worker = Proc.new do |reqs|
      loop do
        req = reqs.receive
        req.resultChan << req.args + 1
      end
    end

    # spawn two workers
    go clientRequests, &worker
    go clientRequests, &worker

    r1 = Request.new(10, resultChan)
    r2 = Request.new(20, resultChan)

    clientRequests << r1
    clientRequests << r2

    # TODO: Blargh.. thread scheduling. Something funky is going on
    # here when requesting two results...
    r1.resultChan.receive.should == 11
    # resultChan.receive.to_s

  end
end
