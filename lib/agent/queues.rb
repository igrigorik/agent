module Agent
  module Queues
    LOCK = Monitor.new

    class << self
      attr_accessor :queues
    end

    self.queues = {}

    def self.register(name, max)
      return queues[name] if queues.has_key?(name)
      LOCK.synchronize{ queues[name] ||= Agent::Queue.new(name, max) }
    end

    def self.remove(name)
      LOCK.synchronize{ queues.delete(name) }
    end
  end
end
