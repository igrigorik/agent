module Agent
  module Transport

    class MemoryQueue
      attr_accessor :que, :monitor, :cvar
      def initialize
        @que     = []
        @monitor = Monitor.new
        @cvar    = @monitor.new_cond
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

        @name = name
        @max = max

        Queue.register(name)
      end

      %w[que monitor cvar].each do |attr|
        define_method attr do
          begin
            Queue.send(:class_variable_get, :"@@__agent_queue_#{@name}__").send attr
          rescue NameError
            retry
          end
        end
      end

      def close
        Queue.send(:remove_class_variable, :"@@__agent_queue_#{@name}__")
      end

      def size;   que.size; end
      def length; que.size; end

      def push?; max > size; end
      def push(obj)
        monitor.synchronize {
          cvar.wait_while{ que.length >= @max }
          que.push obj
          cvar.signal
        }
      end
      alias << push
      alias enq push

      def pop?; size > 0; end
      def pop(*args)
        monitor.synchronize {
          cvar.wait_while{ que.empty? }

          retval = que.shift
          cvar.signal

          retval
        }
      end
      alias shift pop
      alias deq pop

      def async?; @max > 1; end

      def send(msg, nonblock = false)
        monitor.synchronize {
          raise ThreadError, "buffer full" if nonblock && que.length >= @max
          push(msg)
        }
      end

      def receive(nonblock = false)
        monitor.synchronize {
          raise ThreadError, "buffer empty" if nonblock && que.empty?
          pop
        }
      end

    end
  end
end
