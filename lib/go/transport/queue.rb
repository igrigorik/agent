module Go
  module Transport
    class Queue < SizedQueue

      @@registry = {}

      def initialize(name, num = 1)
        @name = name
        super(num)

        # check if this name is already registered
        # and if so, initialize to existing queue
        # otherwise, register for future use
        if que = @@registry[name]
          @que = que
        else
          @@registry[name] = @que
        end
      end

      def async?; @max > 1; end

      def send(msg, nonblock = false)
        raise ThreadError, "buffer full" if nonblock && @que.length >= @max
        push(msg)
      end

      def receive(nonblock = false)
        raise ThreadError, "buffer empty" if nonblock && @que.empty?
        pop
      end

      def close
        @@registry.delete @name
      end

    end
  end
end
