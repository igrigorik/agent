require "agent/queue/buffered"
require "agent/queue/unbuffered"
require "agent/errors"

module Agent
  class Queue
    attr_reader :type, :queue, :operations, :pushes, :pops, :mutex

    def initialize(type)
      @type = type

      raise Errors::Untyped unless @type
      raise Errors::InvalidType unless @type.is_a?(Module)

      @closed = false

      @queue      = []
      @operations = []
      @pushes     = []
      @pops       = []

      @mutex = Mutex.new

      reset_custom_state
    end

    def buffered?
      # implement in subclass
      raise Errors::NotImplementedError
    end

    def unbuffered?
      # implement in subclass
      raise Errors::NotImplementedError
    end

    def pop?
      # implement in subclass
      raise Errors::NotImplementedError
    end

    def push?
      # implement in subclass
      raise Errors::NotImplementedError
    end

    def close
      mutex.synchronize do
        raise Errors::ChannelClosed if @closed
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

    def push(object, options={})
      raise Errors::InvalidType unless object.is_a?(@type)

      push = Push.new(object, options)

      mutex.synchronize do
        raise Errors::ChannelClosed if @closed
        operations << push
        pushes << push
        process
      end

      return push if options[:deferred]

      push.wait
    end

    def pop(options={})
      pop = Pop.new(options)

      mutex.synchronize do
        pop.close if @closed
        operations << pop
        pops << pop
        process
      end

      return pop if options[:deferred]

      ok = pop.wait
      [pop.object, ok]
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
      raise Errors::NotImplementedError
    end

  end
end
