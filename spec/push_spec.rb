require "spec_helper"

describe Agent::Push do

  context "in its basic operation" do
    before do
      @push = Agent::Push.new("1")
      @ack = channel!(Time)
    end

    it "should close" do
      expect(@push).not_to be_closed
      @push.close
      expect(@push).to be_closed
    end

    it "should run multiple times" do
      i = 0
      @push.receive{|v| i += 1 }
      expect(@push).to be_sent
      @push.receive{|v| i += 1 }
      expect(i).to eq(2)
    end

    it "should continue when sent" do
      go!{ @push.wait; @ack.send(Time.now) }
      sleep 0.2
      @push.receive{|v|}

      s, _ = @ack.receive

      expect(Time.now - s).to be_within(0.02).of(0)
    end

    it "should raise an error on the waiter when closed" do
      go!{ sleep 0.1; @push.close }
      expect{ @push.wait }.to raise_error(Agent::Errors::ChannelClosed)
    end

    it "be able to be gracefully rolled back" do
      expect(@push).not_to be_sent
      @push.receive{|v| raise Agent::Errors::Rollback }
      expect(@push).not_to be_sent
    end
  end

  context "marshaling" do
    let(:object){ "foo" }
    let(:skip_marshal){ false }
    let(:push){ Agent::Push.new(object, :skip_marshal => skip_marshal) }

    it "makes a copy of the object" do
      expect(push.object).to eq(object)
      expect(push.object.object_id).not_to eq(object.object_id)
    end

    context "with an object type that skips marshaling" do
      let(:object){ ::Queue.new }

      it "does not make a copy of the object" do
        expect(push.object).to eq(object)
        expect(push.object.object_id).to eq(object.object_id)
      end
    end

    context "when skip_marshal is true" do
      let(:skip_marshal){ true }

      it "does not make a copy of the object" do
        expect(push.object).to eq(object)
        expect(push.object.object_id).to eq(object.object_id)
      end
    end
  end

  context "with a blocking_once" do
    before do
      @blocking_once = Agent::BlockingOnce.new
      @push = Agent::Push.new("1", :blocking_once => @blocking_once)
    end

    it "should only send only once" do
      i = 0

      expect(@blocking_once).not_to be_performed
      @push.receive{|v| i += 1 }
      expect(@push).to be_sent
      expect(@blocking_once).to be_performed

      @push.receive{|v| i += 1 }
      expect(i).to eq(1)

      expect{@push.receive{raise "an error"} }.not_to raise_error
    end

    it "be able to be gracefully rolled back" do
      expect(@blocking_once).not_to be_performed
      expect(@push).not_to be_sent
      @push.receive{|v| raise Agent::Errors::Rollback }
      expect(@blocking_once).not_to be_performed
      expect(@push).not_to be_sent
    end
  end

  context "with a notifier" do
    before do
      @notifier = Agent::Notifier.new
      @push = Agent::Push.new("1", :notifier => @notifier)
    end

    it "should notify when being sent" do
      expect(@notifier).not_to be_notified
      @push.receive{|v|}
      expect(@notifier).to be_notified
    end

    it "should notify when being closed" do
      expect(@notifier).not_to be_notified
      @push.close
      expect(@notifier).to be_notified
    end
  end

end
