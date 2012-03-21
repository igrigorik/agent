module Agent
  module Queues
    LOCK = Mutex.new

    class << self
      attr_accessor :queues
    end

    self.queues = {}

    def self.register(name, max)
      LOCK.synchronize do
        queue = queues[name]
        return queue if queue

        raise InvalidQueueSize, "queue size must be at least 0" unless max >= 0

        if max > 0
          queues[name] = Agent::Queue::Buffered.new(max)
        else
          queues[name] = Agent::Queue::Unbuffered.new
        end
      end
    end

    def self.delete(name)
      LOCK.synchronize{ queues.delete(name) }
    end

    def self.[](name)
      LOCK.synchronize{ queues[name] }
    end

    def self.clear
      LOCK.synchronize{ queues.clear }
    end
  end
end
