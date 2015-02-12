require "spec_helper"

describe Agent::Queue do

  context "with an buffered queue" do
    before do
      @queue = Agent::Queue::Buffered.new(String, 2)
    end

    it "should be buffered" do
      expect(@queue).to be_buffered
    end

    it "should not be unbuffered" do
      expect(@queue).not_to be_unbuffered
    end

    it "should raise an error if the queue size is <= 0" do
      expect{ Agent::Queue::Buffered.new(String, 0) }.to raise_error(Agent::Errors::InvalidQueueSize)
      expect{ Agent::Queue::Buffered.new(String, -1) }.to raise_error(Agent::Errors::InvalidQueueSize)
    end

    it "should raise an erro when an object of an invalid type is pushed" do
      expect { @queue.push(1) }.to raise_error(Agent::Errors::InvalidType)
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(i.to_s, :deferred => true) }

      previous = -1

      20.times do |i|
        o = @queue.pop[0].to_i
        expect(o).to be > previous
        previous = o
      end
    end

    context "when the queue is empty" do
      it "should hold any attempts to pop from it" do
        expect(@queue.operations).to be_empty
        @queue.pop(:deferred => true)
        expect(@queue.operations).not_to be_empty
      end

      it "should be able to be pushed to" do
        @queue.push("1")
      end

      it "should increase in size when pushed to" do
        expect(@queue.size).to eq(0)
        @queue.push("1")
        expect(@queue.size).to eq(1)
      end

      it "should be pushable" do
        expect(@queue.push?).to eq(true)
      end

      it "should not be poppable" do
        expect(@queue.pop?).to eq(false)
      end
    end

    context "when there are elements in the queue and still space left" do
      before do
        @queue.push("1")
      end

      it "should be able to be pushed to" do
        @queue.push("1")
      end

      it "should increase in size when pushed to" do
        expect(@queue.size).to eq(1)
        @queue.push("1")
        expect(@queue.size).to eq(2)
      end

      it "should be able to be popped from" do
        expect(@queue.pop[0]).to eq("1")
      end

      it "should decrease in size when popped from" do
        expect(@queue.size).to eq(1)
        @queue.pop
        expect(@queue.size).to eq(0)
      end

      it "should be pushable" do
        expect(@queue.push?).to eq(true)
      end

      it "should be poppable" do
        expect(@queue.pop?).to eq(true)
      end
    end

    context "when the queue is full" do
      before do
        2.times { @queue.push("1") }
      end

      it "should hold any attempts to push to it" do
        expect(@queue.operations).to be_empty
        @queue.push("1", :deferred => true)
        expect(@queue.operations).not_to be_empty
      end

      it "should be able to be popped from" do
        expect(@queue.pop[0]).to eq("1")
      end

      it "should not be pushable" do
        expect(@queue.push?).to eq(false)
      end

      it "should be poppable" do
        expect(@queue.pop?).to eq(true)
      end
    end

    context "when being closed" do
      before do
        @push1, @push2, @push3 = (1..3).map{ @queue.push("1", :deferred => true) }
      end

      it "should go from open to closed" do
        expect(@queue).not_to be_closed
        expect(@queue).to be_open
        @queue.close
        expect(@queue).to be_closed
        expect(@queue).not_to be_open
      end

      it "should close all the waiting operations" do
        expect(@push1).to be_sent
        expect(@push2).to be_sent
        expect(@push3).not_to be_sent
        expect(@push3).not_to be_closed

        @queue.close

        expect(@push3).to be_closed
      end

      it "should clear all waiting operations" do
        expect(@queue.operations.size).to   eq(1)
        expect(@queue.pushes.size).to eq(1)
        @queue.close
        expect(@queue.operations.size).to eq(0)
        expect(@queue.pushes.size).to eq(0)
      end

      it "should clear all elements at rest" do
        expect(@queue.queue.size).to eq(2)
        @queue.close
        expect(@queue.queue.size).to eq(0)
      end

      context "after it is closed" do
        before{ @queue.close }

        it "should raise an error when #close is called again" do
          expect{ @queue.close }.to raise_error(Agent::Errors::ChannelClosed)
        end

        it "should raise an error when a value is pushed onto the queue" do
          expect{ @queue.push("1") }.to raise_error(Agent::Errors::ChannelClosed)
        end

        it "should return [nil, false] when popping from the queue" do
          expect(@queue.pop).to eq([nil, false])
        end
      end
    end

    context "when removing operations" do
      before do
        @pushes = (1..8).map{|i| @queue.push(i.to_s, :deferred => true) }
      end

      it "should remove the operations" do
        removable_pushes = @pushes.values_at(5, 6) # values "6" and "7"
        @queue.remove_operations(removable_pushes)
        while @queue.pop?
          i = @queue.pop[0]
          expect(i).not_to be_nil
          expect(i).not_to eq("6")
          expect(i).not_to eq("7")
        end
      end
    end
  end

  context "with a unbuffered queue" do
    before do
      @queue = Agent::Queue::Unbuffered.new(String)
    end

    it "should not be buffered" do
      expect(@queue).not_to be_buffered
    end

    it "should be unbuffered" do
      expect(@queue).to be_unbuffered
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(i.to_s, :deferred => true) }

      previous = -1

      20.times do |i|
        o = @queue.pop[0].to_i
        expect(o).to be > previous
        previous = o
      end
    end

    context "when there are no operations waiting" do
      it "should not be poppable" do
        expect(@queue.pop?).to eq(false)
      end

      it "should not be pushable" do
        expect(@queue.push?).to eq(false)
      end

      it "should queue pushes" do
        expect(@queue.operations.size).to eq(0)
        push = @queue.push("1", :deferred => true)
        expect(push).not_to be_sent
        expect(@queue.operations.size).to eq(1)
      end

      it "should queue pops" do
        expect(@queue.operations.size).to eq(0)
        pop = @queue.pop(:deferred => true)
        expect(pop).not_to be_received
        expect(@queue.operations.size).to eq(1)
      end
    end

    context "when there is a pop waiting" do
      before do
        @pop = @queue.pop(:deferred => true)
      end

      it "should not be poppable" do
        expect(@queue.pop?).to eq(false)
      end

      it "should be pushable" do
        expect(@queue.push?).to eq(true)
      end

      it "should execute a push and the waiting pop immediately" do
        push = @queue.push("1", :deferred => true)
        expect(@pop).to be_received
        expect(push).to be_sent
        expect(@pop.object).to eq("1")
      end

      it "should queue pops" do
        expect(@queue.operations.size).to eq(1)
        pop = @queue.pop(:deferred => true)
        expect(pop).not_to be_received
        expect(@queue.operations.size).to eq(2)
      end
    end

    context "when there is a push waiting" do
      before do
        @push = @queue.push("1", :deferred => true)
      end

      it "should be poppable" do
        expect(@queue.pop?).to eq(true)
      end

      it "should not be pushable" do
        expect(@queue.push?).to eq(false)
      end

      it "should queue pushes" do
        expect(@queue.operations.size).to eq(1)
        push = @queue.push("1", :deferred => true)
        expect(push).not_to be_sent
        expect(@queue.operations.size).to eq(2)
      end

      it "should execute a pop and the waiting push immediately" do
        pop = @queue.pop(:deferred => true)
        expect(@push).to be_sent
        expect(pop).to be_received
        expect(pop.object).to eq("1")
      end
    end

    context "when being closed" do
      before do
        @push1, @push2 = (1..2).map{ @queue.push("1", :deferred => true) }
      end

      it "should go from open to closed" do
        expect(@queue).not_to be_closed
        expect(@queue).to be_open
        @queue.close
        expect(@queue).to be_closed
        expect(@queue).not_to be_open
      end

      it "should close all the waiting operations" do
        expect(@push1).not_to be_sent
        expect(@push1).not_to be_closed
        expect(@push2).not_to be_sent
        expect(@push2).not_to be_closed

        @queue.close

        expect(@push1).to be_closed
        expect(@push2).to be_closed
      end

      it "should clear all waiting operations" do
        expect(@queue.operations.size).to   eq(2)
        expect(@queue.pushes.size).to eq(2)
        @queue.close
        expect(@queue.operations.size).to eq(0)
        expect(@queue.pushes.size).to eq(0)
      end

      context "after it is closed" do
        before{ @queue.close }

        it "should raise an error when #close is called again" do
          expect{ @queue.close }.to raise_error(Agent::Errors::ChannelClosed)
        end

        it "should raise an error when a value is pushed onto the queue" do
          expect{ @queue.push("1") }.to raise_error(Agent::Errors::ChannelClosed)
        end

        it "should return [nil, false] when popping from the queue" do
          expect(@queue.pop).to eq([nil, false])
        end
      end
    end

    context "when removing operations" do
      before do
        @pushes = (1..8).map{|i| @queue.push(i.to_s, :deferred => true) }
      end

      it "should remove the operations" do
        removable_pushes = @pushes.values_at(5, 6) # values "6" and "7"
        @queue.remove_operations(removable_pushes)
        while @queue.pop?
          i = @queue.pop[0]
          expect(i).not_to be_nil
          expect(i).not_to eq("6")
          expect(i).not_to eq("7")
        end
      end
    end
  end

end
