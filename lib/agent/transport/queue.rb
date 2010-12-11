module Agent
  module Transport

    class MemoryQueue
      attr_accessor :que, :wait, :mutex, :cvar
      def initialize
        @que, @wait = [], []
        @mutex = Mutex.new
        @cvar = ConditionVariable.new
      end
    end

    class Queue
      attr_reader :name, :max
      LOCK = Monitor.new

      def self.register(name)
        eval <<-RUBY
          return @@__agent_queue_#{name}__ if defined? @@__agent_queue_#{name}__
          LOCK.synchronize { @@__agent_queue_#{name}__ ||= MemoryQueue.new }
        RUBY
      end

      def initialize(name, max = 1)
        raise ArgumentError, "queue size must be at least 1" unless max > 0

        name = name.to_s.gsub(/[^\w]/, '__')
        @name = name
        @max = max

        Queue.register(name)
      end

      %w[que wait mutex cvar].each do |attr|
        define_method attr do
          Queue.send(:class_variable_get, :"@@__agent_queue_#{@name}__").send attr
        end
      end

      def close
        Queue.send(:remove_class_variable, :"@@__agent_queue_#{@name}__")
      end

      def size;   que.size; end
      def length; que.size; end

      def push?; max > size; end
      def push(obj)
        mutex.synchronize {
          while true
            break if que.length < @max
            cvar.wait(mutex)
          end

          que.push obj
          cvar.signal
        }
      end
      alias << push
      alias enq push

      def pop?; size > 0; end
      def pop(*args)
        mutex.synchronize {
          while true
            break if !que.empty?
            cvar.wait(mutex)
          end

          retval = que.shift
          cvar.signal

          retval
        }
      end
      alias shift pop
      alias deq pop

      def async?; @max > 1; end

      def send(msg, nonblock = false)
        raise ThreadError, "buffer full" if nonblock && que.length >= @max
        push(msg)
      end

      def receive(nonblock = false)
        raise ThreadError, "buffer empty" if nonblock && que.empty?
        pop
      end

    end
  end
end
