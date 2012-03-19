module Agent
  class Queue
    class InvalidQueueSize < Exception; end

    attr_reader :name, :max, :queue, :operations, :push_indexes, :pop_indexes, :monitor

    def initialize(name, max = 1)
      raise InvalidQueueSize, "queue size must be at least 0" unless max >= 0

      @name = name
      @max  = max

      @state = :open

      @queue = []

      @operations   = []
      @push_indexes = []
      @pop_indexes  = []
      @monitor      = Monitor.new
    end

    def close
      monitor.synchronize do
        @state = :closed
        operations.each{|o| o.close }
      end
    end
    def closed?; @state == :closed; end
    def open?;   @state == :open;   end

    def size;   queue.size; end
    def length; queue.size; end

    def push(p)
      monitor.synchronize do
        raise ChannelClosed if closed?
        operations << p
        push_indexes << (operations.size - 1)
        process
      end
    end
    def push?; max > size; end

    def pop(p)
      monitor.synchronize do
        raise ChannelClosed if closed?
        operations << p
        pop_indexes << (operations.size - 1)
        process
      end
    end
    def pop?; size > 0; end

    def async?; @max > 0; end

    def remove_operations(ops)
      monitor.synchronize do
        return if closed?

        ops.each_with_index do |operation, index|
          index = operations.index(operation)
          next unless index
          operations.delete_at(index)
          if operation.is_a?(Push)
            push_indexes.delete(index)
          else
            pop_indexes.delete(index)
          end
        end
      end
    end


  protected

    def process
      if max > 0
        process_async
      else
        process_sync
      end
    end

    def process_async
      return if (push_indexes.empty? || !push?) && (pop_indexes.empty? && !pop?)

      index = 0

      loop do
        if operations[index].is_a?(Push)
          if push?
            operations.delete_at(index).receive do |obj|
              queue.push(obj)
            end
            push_indexes.shift
          elsif pop? && index = pop_indexes[0]
            next
          else
            break
          end
        else # Pop
          if pop?
            operations.delete_at(index).send do
              queue.shift
            end
            pop_indexes.shift
          elsif push? && index = push_indexes[0]
            next
          else
            break
          end
        end

        case operations[0]
        when Push
          if push?
            index = 0
          elsif pop? && index = pop_indexes[0]
            next
          else
            break
          end
        when Pop
          if pop?
            index = 0
          elsif push? && index = push_indexes[0]
            next
          else
            break
          end
        else
          break
        end
      end
    end

    def process_sync
      operation = operations.last

      if operation.is_a?(Push)
        pop_indexes.dup.each_with_index do |pop_index, i|
          pop_operation = operations[pop_index]

          if operation.blocking_once && operation.blocking_once == pop_operation.blocking_once
            next
          end

          error = operation.receive do |value|
            error = pop_operation.send do
              value
            end

            operations.delete_at(pop_index)
            pop_indexes.delete_at(i)
            raise Push::Rollback if error
          end

          if error.nil? || error.message?("already performed")
            operations.pop
            push_indexes.pop
            break
          end
        end
      else # Pop
        push_indexes.dup.each_with_index do |push_index, i|
          push_operation = operations[push_index]

          if operation.blocking_once && operation.blocking_once == push_operation.blocking_once
            next
          end

          error = operation.send do
            value = nil

            error = push_operation.receive do |v|
              value = v
            end

            operations.delete_at(push_index)
            push_indexes.delete_at(i)
            raise Pop::Rollback if error

            value
          end

          if error.nil? || error.message?("already performed")
            operations.pop
            pop_indexes.pop
            break
          end
        end
      end

    end

  end
end
