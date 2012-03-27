require "agent/errors"

module Agent
  module Queues
    LOCK = Mutex.new

    class << self
      attr_accessor :queues
    end

    self.queues = {}

    def self.register(name, type, max)
      raise Errors::Untyped unless type
      raise Errors::InvalidType unless type.is_a?(Module)

      LOCK.synchronize do
        queue = queues[name]

        if queue
          if queue.type == type
            return queue
          else
            raise Errors::InvalidType, "Type #{type.name} is different than the queue's type (#{queue.type.name})"
          end
        end

        raise Errors::InvalidQueueSize, "queue size must be at least 0" unless max >= 0

        if max > 0
          queues[name] = Queue::Buffered.new(type, max)
        else
          queues[name] = Queue::Unbuffered.new(type)
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
