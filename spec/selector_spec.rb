require "spec_helper"

describe Agent::Selector do
  # A "select" statement chooses which of a set of possible communications will
  # proceed. It looks similar to a "switch" statement but with the cases all
  # referring to communication operations.
  #   - http://golang.org/doc/go_spec.html#Select_statements

  it "should yield Selector on select call" do
    select! {|s| expect(s).to be_kind_of Agent::Selector}
  end

  it "should return immediately on empty select block" do
    s = Time.now.to_f
    select! {}

    expect(Time.now.to_f - s).to be_within(0.05).of(0)
  end

  it "should timeout select statement" do
    r, now = [], Time.now.to_f
    select! do |s|
      s.timeout(0.1) { r.push :timeout }
    end

    expect(r.first).to eq(:timeout)
    expect(Time.now.to_f - now).to be_within(0.05).of(0.1)
  end

  it "should not raise an error when a block is missing on default" do
    expect {
      select! do |s|
        s.default
      end
    }.not_to raise_error
  end

  it "should not raise an error when a block is missing on timeout" do
    expect {
      select! do |s|
        s.timeout(1)
        s.default
      end
    }.not_to raise_error
  end

  context "with unbuffered channels" do
    before do
      @c = channel!(Integer)
    end

    after do
      @c.close unless @c.closed?
    end

    it "should evaluate select statements top to bottom" do
      select! do |s|
        s.case(@c, :send, 1)
        s.case(@c, :receive)
        s.default
        expect(s.cases.size).to eq(3)
      end
    end

    it "should not raise an error when a block is missing on receive" do
      expect {
        select! do |s|
          s.case(@c, :receive)
          s.default
        end
      }.not_to raise_error
    end

    it "should not raise an error when a block is missing on send" do
      expect {
        select! do |s|
          s.case(@c, :send, 1)
          s.default
        end
      }.not_to raise_error
    end

    it "should scan all cases to identify available actions and execute first available one" do
      r = []
      go!{ @c.send 1 }

      sleep 0.01 # make sure the goroutine executes, brittle

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.case(@c, :receive) { r.push 2 }
        s.case(@c, :receive) { r.push 3 }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(2)
    end

    it "should evaluate default case immediately if no other cases match" do
      r = []

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.default { r.push :default }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(:default)
    end

    it "should evaluate a matching prior closed channel in preference to the default case" do
      r = []

      @c.close
      select! do |s|
        s.case(@c, :receive) { r.push :from_closed }
        s.default { r.push :default }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(:from_closed)
    end

    it "should raise an error if the channel is closed out from under it and you are sending to it" do
      go!{ sleep 0.25; @c.close }

      expect {
        select! do |s|
          s.case(@c, :send, 1)
        end
      }.to raise_error(Agent::Errors::ChannelClosed)
    end

    it "should not raise an error if the channel is closed out from under it and you are receiving from it" do
      go!{ sleep 0.25; @c.close }

      expect {
        select! do |s|
          s.case(@c, :receive){}
        end
      }.not_to raise_error
    end

    context "select immediately available channel" do
      it "should select read channel" do
        c = channel!(Integer)
        go!{ c.send(1) }

        sleep 0.01 # make sure the goroutine executes, brittle

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        expect(r.size).to eq(1)
        expect(r.first).to eq(:receive)
        c.close
      end

      it "should select write channel" do
        c = channel!(Integer)

        go!{ c.receive }

        sleep 0.01 # make sure the goroutine executes, brittle

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        expect(r.size).to eq(1)
        expect(r.first).to eq(:send)
        c.close
      end
    end

    context "select busy channel" do
      it "should select busy read channel" do
        c = channel!(Integer)
        r = []

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{ sleep(0.2); c.send 1 }

        select! do |s|
          s.case(c, :receive) {|value| r.push value }
        end

        expect(r.size).to eq(1)
        expect(Time.now.to_f - now).to be_within(0.1).of(0.2)
        c.close
      end

      it "should select busy write channel" do
        c = channel!(Integer)

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{sleep(0.2); expect(c.receive[0]).to eq(2 )}

        select! do |s|
          s.case(c, :send, 2)
        end

        expect(Time.now.to_f - now).to be_within(0.1).of(0.2)
        c.close
      end

      it "should select first available channel" do
        # create a write channel and a read channel
        cw  = channel!(Integer)
        cr  = channel!(Integer)
        ack = channel!(TrueClass)

        res = []

        now = Time.now.to_f

        # read channel: wait for 0.3s before pushing a message into it
        go!{ sleep(0.3); cr.send 2 }
        # write channel: wait for 0.1s before consuming the message
        go!{ sleep(0.1); res.push cw.receive[0]; ack.send(true) }

        # wait until one of the channels become available
        # cw should fire first and push '3'
        select! do |s|
          s.case(cr, :receive) {|value| res.push value }
          s.case(cw, :send, 3)
        end

        ack.receive

        expect(res.size).to eq(1)
        expect(res.first).to eq(3)

        # 0.3s goroutine should eventually fire
        expect(cr.receive[0]).to eq(2)

        expect(Time.now.to_f - now).to be_within(0.05).of(0.3)
        cw.close
        cr.close
      end
    end
  end

  context "with buffered channels" do
    before do
      @c = channel!(Integer, 1)
    end

    after do
      @c.close unless @c.closed?
    end

    it "should evaluate select statements top to bottom" do
      select! do |s|
        s.case(@c, :send, 1)
        s.case(@c, :receive)
        expect(s.cases.size).to eq(2)
      end
    end

    it "should not raise an error when a block is missing on receive" do
      expect {
        select! do |s|
          s.case(@c, :receive)
          s.default
        end
      }.not_to raise_error
    end

    it "should not raise an error when a block is missing on send" do
      expect {
        select! do |s|
          s.case(@c, :send, 1)
          s.default
        end
      }.not_to raise_error
    end

    it "should scan all cases to identify available actions and execute first available one" do
      r = []
      @c.send 1

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.case(@c, :receive) { r.push 2 }
        s.case(@c, :receive) { r.push 3 }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(2)
    end

    it "should evaluate default case immediately if no other cases match" do
      r = []

      @c.send(1)

      select! do |s|
        s.case(@c, :send, 1) { r.push 1 }
        s.default { r.push :default }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(:default)
    end

    it "should evaluate a matching prior closed channel in preference to the default case" do
      r = []

      @c.close

      select! do |s|
        s.case(@c, :receive) { r.push :from_closed }
        s.default { r.push :default }
      end

      expect(r.size).to eq(1)
      expect(r.first).to eq(:from_closed)
    end

    it "should raise an error if the channel is closed out from under it and you are sending to it" do
      @c.send(1)

      go!{ sleep 0.25; @c.close }

      expect {
        select! do |s|
          s.case(@c, :send, 1)
        end
      }.to raise_error(Agent::Errors::ChannelClosed)
    end

    it "should not raise an error if the channel is closed out from under it and you are receiving from it" do
      go!{ sleep 0.25; @c.close }

      expect {
        select! do |s|
          s.case(@c, :receive){}
        end
      }.not_to raise_error
    end

    context "select immediately available channel" do
      it "should select read channel" do
        c = channel!(Integer, 1)
        c.send(1)

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        expect(r.size).to eq(1)
        expect(r.first).to eq(:receive)
        c.close
      end

      it "should select write channel" do
        c = channel!(Integer, 1)

        r = []
        select! do |s|
          s.case(c, :send, 1) { r.push :send }
          s.case(c, :receive) { r.push :receive }
          s.default { r.push :empty }
        end

        expect(r.size).to eq(1)
        expect(r.first).to eq(:send)
        c.close
      end
    end

    context "select busy channel" do
      it "should select busy read channel" do
        c = channel!(Integer, 1)
        r = []

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{ sleep(0.2); c.send 1 }

        select! do |s|
          s.case(c, :receive) {|value| r.push value }
        end

        expect(r.size).to eq(1)
        expect(Time.now.to_f - now).to be_within(0.1).of(0.2)
        c.close
      end

      it "should select busy write channel" do
        c = channel!(Integer, 1)
        c.send 1

        # brittle.. counting on select to execute within 0.5s
        now = Time.now.to_f
        go!{sleep(0.2); c.receive }

        select! do |s|
          s.case(c, :send, 2)
        end

        expect(c.receive[0]).to eq(2)
        expect(Time.now.to_f - now).to be_within(0.1).of(0.2)
        c.close
      end

      it "should select first available channel" do
        # create a "full" write channel, and "empty" read channel
        cw  = channel!(Integer, 1)
        cr  = channel!(Integer, 1)
        ack = channel!(TrueClass)

        cw.send(1)

        res = []

        now = Time.now.to_f
        # empty read channel: wait for 0.5s before pushing a message into it
        go!{ sleep(0.5); cr.send(2) }
        # full write channel: wait for 0.2s before consuming the message
        go!{ sleep(0.2); res.push cw.receive[0]; ack.send(true) }

        # wait until one of the channels become available
        # cw should fire first and push '3'
        select! do |s|
          s.case(cr, :receive) {|value| res.push value }
          s.case(cw, :send, 3)
        end

        ack.receive

        # 0.8s goroutine should have consumed the message first
        expect(res.size).to eq(1)
        expect(res.first).to eq(1)

        # send case should have fired, and we should have a message
        expect(cw.receive[0]).to eq(3)

        expect(Time.now.to_f - now).to be_within(0.1).of(0.2)
        cw.close
        cr.close
      end
    end
  end

end
