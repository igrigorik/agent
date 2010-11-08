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
            :reader_wait => [],
            :writer_wait => [],
            :reader_mutex => Mutex.new,
            :writer_mutex => Mutex.new
          }
        end
      end

      def data;         @@registry[@name];  end
      def que;          data[:que]; end
      def reader_wait;  data[:reader_wait]; end
      def writer_wait;  data[:writer_wait]; end
      def reader_mutex; data[:reader_mutex]; end
      def writer_mutex; data[:writer_mutex]; end

      def max; @max; end
      def size; que.size; end
      def length; que.size; end

      def push(obj)
        writer_mutex.synchronize {
          while true
            break if que.length < @max
            writer_wait.push Thread.current
            writer_mutex.sleep
          end

          que.push obj

          begin
            t = reader_wait.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
        }
      end
      alias << push
      alias enq push

      def pop(*args)
        reader_mutex.synchronize {
          while true
            break if !que.empty?
            reader_wait.push Thread.current
            reader_mutex.sleep
          end

          retval = que.shift

          begin
            t = writer_wait.shift
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
