require "spec_helper"

describe Agent::Queue do

  context "with an buffered queue" do
    before do
      @queue = Agent::Queue::Buffered.new(2)
    end

    it "should be buffered" do
      @queue.should be_buffered
    end

    it "should not be unbuffered" do
      @queue.should_not be_unbuffered
    end

    it "should raise an error if the queue size is <= 0" do
      lambda{ Agent::Queue::Buffered.new(0) }.should raise_error(Agent::Queue::Buffered::InvalidQueueSize)
      lambda{ Agent::Queue::Buffered.new(-1) }.should raise_error(Agent::Queue::Buffered::InvalidQueueSize)
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(Agent::Push.new(i)) }

      previous = -1

      20.times do |i|
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.object.should > previous
        previos = pop.object
      end
    end

    context "when the queue is empty" do
      it "should hold any attempts to pop from it" do
        @queue.operations.should be_empty
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.should_not be_received
        @queue.operations.should_not be_empty
      end

      it "should be able to be pushed to" do
        push = Agent::Push.new("1")
        @queue.push(push)
        push.should be_sent
      end

      it "should increase in size when pushed to" do
        @queue.size.should == 0
        @queue.push(Agent::Push.new("1"))
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
        @queue.push(Agent::Push.new("1"))
      end

      it "should be able to be pushed to" do
        push = Agent::Push.new("1")
        @queue.push(push)
        push.should be_sent
      end

      it "should increase in size when pushed to" do
        @queue.size.should == 1
        @queue.push(Agent::Push.new("1"))
        @queue.size.should == 2
      end

      it "should be able to be popped from" do
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.object.should == "1"
        pop.should be_received
      end

      it "should decrease in size when popped from" do
        @queue.size.should == 1
        @queue.pop(Agent::Pop.new)
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
        2.times { @queue.push(Agent::Push.new("1")) }
      end

      it "should hold any attempts to push to it" do
        @queue.operations.should be_empty
        push = Agent::Push.new("1")
        @queue.push(push)
        push.should_not be_sent
        @queue.operations.should_not be_empty
      end

      it "should be able to be popped from" do
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.object.should == "1"
        pop.should be_received
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
        @push1, @push2, @push3 = (1..3).map{ Agent::Push.new("1") }
        @queue.push(@push1)
        @queue.push(@push2)
        @queue.push(@push3)
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
        lambda{ @queue.close }.should raise_error(Agent::ChannelClosed)
        lambda{ @queue.push(Agent::Push.new("1")) }.should raise_error(Agent::ChannelClosed)
        lambda{ @queue.pop(Agent::Push.new("1")) }.should raise_error(Agent::ChannelClosed)
      end
    end

    context "when removing operations" do
      before do
        @pushes = (1..8).map{|i| Agent::Push.new(i.to_s) }
        @pushes.each{|push| @queue.push(push) }
      end

      it "should remove the operations" do
        removable_pushes = @pushes.values_at(5, 6) # values "6" and "7"
        @queue.remove_operations(removable_pushes)
        while @queue.pop?
          pop = Agent::Pop.new
          @queue.pop(pop)
          pop.object.should_not == "6"
          pop.object.should_not == "7"
        end
      end
    end
  end

  context "with a unbuffered queue" do
    before do
      @queue = Agent::Queue::Unbuffered.new
    end

    it "should not be buffered" do
      @queue.should_not be_buffered
    end

    it "should be unbuffered" do
      @queue.should be_unbuffered
    end

    it "should enqueue and dequeue in order" do
      20.times{|i| @queue.push(Agent::Push.new(i)) }

      previous = -1

      20.times do |i|
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.object.should > previous
        previos = pop.object
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
        push = Agent::Push.new("1")
        @queue.push(push)
        push.should_not be_sent
        @queue.operations.size.should == 1
      end

      it "should queue pops" do
        @queue.operations.size.should == 0
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.should_not be_received
        @queue.operations.size.should == 1
      end
    end

    context "when there is a pop waiting" do
      before do
        @pop = Agent::Pop.new
        @queue.pop(@pop)
      end

      it "should not be poppable" do
        @queue.pop?.should == false
      end

      it "should be pushable" do
        @queue.push?.should == true
      end

      it "should execute a push and the waiting pop immediately" do
        push = Agent::Push.new("1")
        @queue.push(push)
        @pop.should be_received
        push.should be_sent
        @pop.object.should == "1"
      end

      it "should queue pops" do
        @queue.operations.size.should == 1
        pop = Agent::Pop.new
        @queue.pop(pop)
        pop.should_not be_received
        @queue.operations.size.should == 2
      end
    end

    context "when there is a push waiting" do
      before do
        @push = Agent::Push.new("1")
        @queue.push(@push)
      end

      it "should be poppable" do
        @queue.pop?.should == true
      end

      it "should not be pushable" do
        @queue.push?.should == false
      end

      it "should queue pushes" do
        @queue.operations.size.should == 1
        push = Agent::Push.new("1")
        @queue.push(push)
        push.should_not be_sent
        @queue.operations.size.should == 2
      end

      it "should execute a pop and the waiting push immediately" do
        pop = Agent::Pop.new
        @queue.pop(pop)
        @push.should be_sent
        pop.should be_received
        pop.object.should == "1"
      end
    end

    context "when being closed" do
      before do
        @push1, @push2 = (1..2).map{ Agent::Push.new("1") }
        @queue.push(@push1)
        @queue.push(@push2)
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
        lambda{ @queue.close }.should raise_error(Agent::ChannelClosed)
        lambda{ @queue.push(Agent::Push.new("1")) }.should raise_error(Agent::ChannelClosed)
        lambda{ @queue.pop(Agent::Push.new("1")) }.should raise_error(Agent::ChannelClosed)
      end
    end

    context "when removing operations" do
      before do
        @pushes = (1..8).map{|i| Agent::Push.new(i.to_s) }
        @pushes.each{|push| @queue.push(push) }
      end

      it "should remove the operations" do
        removable_pushes = @pushes.values_at(5, 6) # values "6" and "7"
        @queue.remove_operations(removable_pushes)
        while @queue.pop?
          pop = Agent::Pop.new
          @queue.pop(pop)
          pop.object.should_not == "6"
          pop.object.should_not == "7"
        end
      end
    end
  end

end
