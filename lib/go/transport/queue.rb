module Go
  module Transport

    class Queue

      @@registry = {}

      def initialize(name, max = 1)
        raise ArgumentError, "queue size must be positive" unless max > 0

        @name = name
        @max = max

        if !@@registry[@name]
          @@registry[@name] = {
            :que => [],
            :wait => [],
            :mutex => Mutex.new
          }
        end
      end

      def data;         @@registry[@name];  end
      def que;          data[:que]; end
      def wait;  data[:wait]; end
      def mutex; data[:mutex]; end

      def max; @max; end
      def size; que.size; end
      def length; que.size; end

      def push(obj)
        mutex.synchronize {
          while true
            break if que.length < @max
            wait.push Thread.current
            mutex.sleep
          end

          que.push obj

          begin
            t = wait.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
        }
      end
      alias << push
      alias enq push

      def pop(*args)
        mutex.synchronize {
          while true
            break if !que.empty?
            wait.push Thread.current
            mutex.sleep
          end

          retval = que.shift

          begin
            t = wait.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end

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

      def close
        @@registry.delete @name
      end

    end
  end
end
