require "agent/queue"
require "agent/errors"

module Agent
  class Queue
    class Buffered < Queue
      attr_reader :size, :max

      def initialize(type, max=1)
        raise Errors::InvalidQueueSize, "queue size must be at least 1" unless max >= 1
        super(type)
        @max = max
      end

      def buffered?;   true; end
      def unbuffered?; false;  end

      def push?; @max > @size; end
      def pop?;  @size > 0;    end

    protected

      def reset_custom_state
        @size = @queue.size
      end

      def process
        return if (pops.empty? && !push?) || (pushes.empty? && !pop?)

        operation = operations.first

        loop do
          if operation.is_a?(Push)
            if push?
              operation.receive do |obj|
                @size += 1
                queue.push(obj)
              end
              operations.delete(operation)
              pushes.delete(operation)
            elsif pop? && operation = pops[0]
              next
            else
              break
            end
          else # Pop
            if pop?
              operation.send do
                @size -= 1
                queue.shift
              end
              operations.delete(operation)
              pops.delete(operation)
            elsif push? && operation = pushes[0]
              next
            else
              break
            end
          end

          operation = operations[0]
          break unless operation
        end
      end

    end
  end
end
