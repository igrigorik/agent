require "agent/queue"

module Agent
  class Queue
    class Unbuffered < Queue

      attr_reader :waiting_pushes, :waiting_pops

      def buffered?;   false; end
      def unbuffered?; true;  end

      def push?; @waiting_pops > 0;   end
      def pop?;  @waiting_pushes > 0; end

    protected

      def reset_custom_state
        @waiting_pushes = pushes.size
        @waiting_pops   = pops.size
      end

      def process
        operation = operations.last

        if operation.is_a?(Push)
          @waiting_pushes += 1

          pops.dup.each do |pop_operation|
            if operation.blocking_once && operation.blocking_once == pop_operation.blocking_once
              next
            end

            error = operation.receive do |value|
              error = pop_operation.send do
                value
              end

              @waiting_pops -= 1
              operations.delete(pop_operation)
              pops.delete(pop_operation)
              raise Push::Rollback if error
            end

            if error.nil? || error.message?("already performed")
              @waiting_pushes -= 1
              operations.pop
              pushes.pop
              break
            end
          end
        else # Pop
          @waiting_pops += 1

          pushes.dup.each do |push_operation|
            if operation.blocking_once && operation.blocking_once == push_operation.blocking_once
              next
            end

            error = operation.send do
              value = nil

              error = push_operation.receive do |v|
                value = v
              end

              @waiting_pushes -= 1
              operations.delete(push_operation)
              pushes.delete(push_operation)
              raise Pop::Rollback if error

              value
            end

            if error.nil? || error.message?("already performed")
              @waiting_pops -= 1
              operations.pop
              pops.pop
              break
            end
          end
        end

      end

    end
  end
end
