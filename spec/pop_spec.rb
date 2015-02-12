require "spec_helper"

describe Agent::Pop do

  context "in its basic operation" do
    before do
      @pop = Agent::Pop.new
      @ack = channel!(Time)
    end

    it "should close" do
      expect(@pop).not_to be_closed
      @pop.close
      expect(@pop).to be_closed
    end

    it "should run multiple times" do
      @pop.send{1}
      expect(@pop).to be_received
      @pop.send{2}
      expect(@pop.object).to eq(2)
    end

    it "should continue when received" do
      go!{ @pop.wait; @ack.send(Time.now) }
      sleep 0.2
      @pop.send{1}

      s, _ = @ack.receive

      expect(Time.now - s).to be_within(0.01).of(0)
    end

    it "should continue when closed" do
      go!{ @pop.wait; @ack.send(Time.now) }
      sleep 0.2
      @pop.close

      s, _ = @ack.receive

      expect(Time.now - s).to be_within(0.01).of(0)
    end

    it "should be able to be gracefully rolled back" do
      expect(@pop).not_to be_received
      @pop.send{ raise Agent::Errors::Rollback }
      expect(@pop).not_to be_received
    end

    it "should continue when it was already closed" do
      @pop.close

      go!{ @pop.wait; @ack.send(Time.now) }

      sleep 0.2

      s, _ = @ack.receive

      expect(Time.now - s).to be_within(0.01).of(0.2)
    end
  end

  context "with a blocking_once" do
    before do
      @blocking_once = Agent::BlockingOnce.new
      @pop = Agent::Pop.new(:blocking_once => @blocking_once)
    end

    it "should only send only once" do
      expect(@blocking_once).not_to be_performed
      @pop.send{1}
      expect(@pop).to be_received
      expect(@blocking_once).to be_performed
      expect(@pop.object).to eq(1)

      @pop.send{2}
      expect(@pop.object).to eq(1)

      expect{@pop.send{raise "an error"} }.not_to raise_error
    end

    it "be able to be gracefully rolled back" do
      expect(@blocking_once).not_to be_performed
      expect(@pop).not_to be_received
      @pop.send{ raise Agent::Errors::Rollback }
      expect(@blocking_once).not_to be_performed
      expect(@pop).not_to be_received
    end

    it "should send only once even when it is closed" do
      @pop.close
      expect(@blocking_once).not_to be_performed
      @pop.send{1}
      expect(@pop).to be_received
      expect(@blocking_once).to be_performed
      expect(@pop.object).to be_nil

      @pop.send{2}
      expect(@pop.object).to be_nil

      expect{@pop.send{raise "an error"} }.not_to raise_error
    end
  end

  context "with a notifier" do
    before do
      @notifier = Agent::Notifier.new
      @pop = Agent::Pop.new(:notifier => @notifier)
    end

    it "should notify when being sent" do
      expect(@notifier).not_to be_notified
      @pop.send{1}
      expect(@notifier).to be_notified
    end

    it "should notify when being closed" do
      expect(@notifier).not_to be_notified
      @pop.close
      expect(@notifier).to be_notified
    end
  end

end
