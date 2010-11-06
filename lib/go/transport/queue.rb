module Go
  module Transport
    class Queue < SizedQueue

      def initialize(num = 1); super; end
      def async?; @max > 1; end

      def send(msg, nonblock = false)
        raise ThreadError, "buffer full" if nonblock && @que.length >= @max
        push(msg)
      end

      def receive(nonblock = false)
        raise ThreadError, "buffer empty" if nonblock && @que.empty?
        pop
      end

    end
  end
end
