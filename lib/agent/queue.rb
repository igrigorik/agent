require "agent/queue/buffered"
require "agent/queue/unbuffered"

module Agent
  class Queue
    class NotImplementedError < Exception; end

    attr_reader :queue, :operations, :pushes, :pops, :mutex

    def initialize
      @closed = false

      @queue = []

      @operations   = []
      @pushes       = []
      @pops         = []
      @mutex        = Mutex.new

      reset_custom_state
    end

    def buffered?
      # implement in subclass
      raise NotImplementedError
    end

    def unbuffered?
      # implement in subclass
      raise NotImplementedError
    end

    def pop?
      # implement in subclass
      raise NotImplementedError
    end

    def push?
      # implement in subclass
      raise NotImplementedError
    end

    def close
      mutex.synchronize do
        raise ChannelClosed if @closed
        @closed = true
        @operations.each{|o| o.close }
        @operations.clear
        @queue.clear
        @pushes.clear
        @pops.clear

        reset_custom_state
      end
    end

    def closed?; @closed; end
    def open?;   !@closed;   end

    def push(p)
      mutex.synchronize do
        raise ChannelClosed if @closed
        operations << p
        pushes << p
        process
      end
    end

    def pop(p)
      mutex.synchronize do
        raise ChannelClosed if @closed
        operations << p
        pops << p
        process
      end
    end

    def remove_operations(ops)
      mutex.synchronize do
        return if @closed

        ops.each do |operation|
          operations.delete(operation)
        end

        pushes.clear
        pops.clear

        operations.each do |operation|
          if operation.is_a?(Push)
            pushes << operation
          else
            pops << operation
          end
        end

        reset_custom_state
      end
    end


  protected

    def reset_custom_state
      # implement in subclass...or not...
    end

    def process
      # implement in subclass
      raise NotImplementedError
    end

  end
end
