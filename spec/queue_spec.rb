require "spec_helper"

describe Agent::Queue do

  context "with an buffered queue" do
    before do
      @queue = Agent::Queue::Buffered.new(String, 2)
    end

    it "should be buffered" do
      @queue.should be_buffered
    end

    it "should not be unbuffered" do
      @queue.should_not be_unbuffered
    end

    it "should raise an error if the queue size is <= 0" do
      lambda{ Agent::Queue::Buffered.new(String, 0) }.should raise_error(Agent::Errors::InvalidQueueSize)
      lambda{ Agent::Queue::Buffered.new(String, -1) }.should raise_error(Agent::Errors::InvalidQueueSize)
    end

    it "should raise an erro when an object of an invalid type is pushed" do
      lambda { @queue.push(1) }.should raise_error(Agent::Errors::InvalidType)
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(i.to_s, :deferred => true) }

      previous = -1

      20.times do |i|
        o = @queue.pop[0].to_i
        o.should > previous
        previous = o
      end
    end

    context "when the queue is empty" do
      it "should hold any attempts to pop from it" do
        @queue.operations.should be_empty
        @queue.pop(:deferred => true)
        @queue.operations.should_not be_empty
      end

      it "should be able to be pushed to" do
        @queue.push("1")
      end

      it "should increase in size when pushed to" do
        @queue.size.should == 0
        @queue.push("1")
        @queue.size.should == 1
      end

      it "should be pushable" do
        @queue.push?.should == true
      end

      it "should not be poppable" do
        @queue.pop?.should == false
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
        @queue.size.should == 1
        @queue.push("1")
        @queue.size.should == 2
      end

      it "should be able to be popped from" do
        @queue.pop[0].should == "1"
      end

      it "should decrease in size when popped from" do
        @queue.size.should == 1
        @queue.pop
        @queue.size.should == 0
      end

      it "should be pushable" do
        @queue.push?.should == true
      end

      it "should be poppable" do
        @queue.pop?.should == true
      end
    end

    context "when the queue is full" do
      before do
        2.times { @queue.push("1") }
      end

      it "should hold any attempts to push to it" do
        @queue.operations.should be_empty
        @queue.push("1", :deferred => true)
        @queue.operations.should_not be_empty
      end

      it "should be able to be popped from" do
        @queue.pop[0].should == "1"
      end

      it "should not be pushable" do
        @queue.push?.should == false
      end

      it "should be poppable" do
        @queue.pop?.should == true
      end
    end

    context "when being closed" do
      before do
        @push1, @push2, @push3 = (1..3).map{ @queue.push("1", :deferred => true) }
      end

      it "should go from open to closed" do
        @queue.should_not be_closed
        @queue.should be_open
        @queue.close
        @queue.should be_closed
        @queue.should_not be_open
      end

      it "should close all the waiting operations" do
        @push1.should be_sent
        @push2.should be_sent
        @push3.should_not be_sent
        @push3.should_not be_closed

        @queue.close

        @push3.should be_closed
      end

      it "should clear all waiting operations" do
        @queue.operations.size.should   == 1
        @queue.pushes.size.should == 1
        @queue.close
        @queue.operations.size.should == 0
        @queue.pushes.size.should == 0
      end

      it "should clear all elements at rest" do
        @queue.queue.size.should == 2
        @queue.close
        @queue.queue.size.should == 0
      end

      it "should raise an error when being acted upon afterwards" do
        @queue.close
        lambda{ @queue.close }.should raise_error(Agent::Errors::ChannelClosed)
        lambda{ @queue.push("1") }.should raise_error(Agent::Errors::ChannelClosed)
        lambda{ @queue.pop }.should raise_error(Agent::Errors::ChannelClosed)
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
          i.should_not be_nil
          i.should_not == "6"
          i.should_not == "7"
        end
      end
    end
  end

  context "with a unbuffered queue" do
    before do
      @queue = Agent::Queue::Unbuffered.new(String)
    end

    it "should not be buffered" do
      @queue.should_not be_buffered
    end

    it "should be unbuffered" do
      @queue.should be_unbuffered
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(i.to_s, :deferred => true) }

      previous = -1

      20.times do |i|
        o = @queue.pop[0].to_i
        o.should > previous
        previous = o
      end
    end

    context "when there are no operations waiting" do
      it "should not be poppable" do
        @queue.pop?.should == false
      end

      it "should not be pushable" do
        @queue.push?.should == false
      end

      it "should queue pushes" do
        @queue.operations.size.should == 0
        push = @queue.push("1", :deferred => true)
        push.should_not be_sent
        @queue.operations.size.should == 1
      end

      it "should queue pops" do
        @queue.operations.size.should == 0
        pop = @queue.pop(:deferred => true)
        pop.should_not be_received
        @queue.operations.size.should == 1
      end
    end

    context "when there is a pop waiting" do
      before do
        @pop = @queue.pop(:deferred => true)
      end

      it "should not be poppable" do
        @queue.pop?.should == false
      end

      it "should be pushable" do
        @queue.push?.should == true
      end

      it "should execute a push and the waiting pop immediately" do
        push = @queue.push("1", :deferred => true)
        @pop.should be_received
        push.should be_sent
        @pop.object.should == "1"
      end

      it "should queue pops" do
        @queue.operations.size.should == 1
        pop = @queue.pop(:deferred => true)
        pop.should_not be_received
        @queue.operations.size.should == 2
      end
    end

    context "when there is a push waiting" do
      before do
        @push = @queue.push("1", :deferred => true)
      end

      it "should be poppable" do
        @queue.pop?.should == true
      end

      it "should not be pushable" do
        @queue.push?.should == false
      end

      it "should queue pushes" do
        @queue.operations.size.should == 1
        push = @queue.push("1", :deferred => true)
        push.should_not be_sent
        @queue.operations.size.should == 2
      end

      it "should execute a pop and the waiting push immediately" do
        pop = @queue.pop(:deferred => true)
        @push.should be_sent
        pop.should be_received
        pop.object.should == "1"
      end
    end

    context "when being closed" do
      before do
        @push1, @push2 = (1..2).map{ @queue.push("1", :deferred => true) }
      end

      it "should go from open to closed" do
        @queue.should_not be_closed
        @queue.should be_open
        @queue.close
        @queue.should be_closed
        @queue.should_not be_open
      end

      it "should close all the waiting operations" do
        @push1.should_not be_sent
        @push1.should_not be_closed
        @push2.should_not be_sent
        @push2.should_not be_closed

        @queue.close

        @push1.should be_closed
        @push2.should be_closed
      end

      it "should clear all waiting operations" do
        @queue.operations.size.should   == 2
        @queue.pushes.size.should == 2
        @queue.close
        @queue.operations.size.should == 0
        @queue.pushes.size.should == 0
      end

      it "should raise an error when being acted upon afterwards" do
        @queue.close
        lambda{ @queue.close }.should raise_error(Agent::Errors::ChannelClosed)
        lambda{ @queue.push("1") }.should raise_error(Agent::Errors::ChannelClosed)
        lambda{ @queue.pop }.should raise_error(Agent::Errors::ChannelClosed)
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
          i.should_not be_nil
          i.should_not == "6"
          i.should_not == "7"
        end
      end
    end
  end

end
