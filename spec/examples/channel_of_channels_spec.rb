require "spec_helper"

describe "Channel of Channels" do

  Request = Struct.new(:args, :resultChan)

  it "should be able to pass channels as first class citizens" do
    server = Proc.new do |reqs|
      2.times do |n|
        res = Request.new(n, channel!(Integer))

        reqs << res
        res.resultChan.receive[0].should == n+1
        res.resultChan.close
      end
    end

    worker = Proc.new do |reqs|
      loop do
        req, ok = reqs.receive
        break unless ok
        req.resultChan << req.args+1
      end
    end

    clientRequests = channel!(Request)

    s = go!(clientRequests, &server)
    c = go!(clientRequests, &worker)

    s.join
    clientRequests.close
  end

  it "should work with multiple workers" do
    worker = Proc.new do |reqs|
      loop do
        req, _ = reqs.receive
        req.resultChan << req.args+1
      end
    end

    clientRequests = channel!(Request)

    # start multiple workers
    go!(clientRequests, &worker)
    go!(clientRequests, &worker)

    # start server
    s = go! clientRequests do |reqs|
      2.times do |n|
        res = Request.new(n, channel!(Integer))

        reqs << res
        res.resultChan.receive[0].should == n+1
        res.resultChan.close
      end
    end

    s.join
  end
end