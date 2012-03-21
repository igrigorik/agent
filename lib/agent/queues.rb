module Agent
  module Queues
    LOCK = Monitor.new

    class << self
      attr_accessor :queues
    end

    self.queues = {}

    def self.register(name, max)
      LOCK.synchronize{ queues[name] ||= Agent::Queue.new(name, max) }
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
