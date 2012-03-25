require "agent/uuid"
require "agent/push"
require "agent/pop"
require "agent/queues"
require "agent/errors"

module Agent
  def self.channel!(*args)
    Channel.new(*args)
  end

  class Channel
    attr_reader :name, :direction

    def initialize(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}

      @type = args.shift
      raise Errors::Untyped unless @type
      # Module includes both classes and modules
      raise Errors::InvalidType unless @type.is_a?(Module)

      @max         = args.shift  || 0
      @closed      = false
      @name        = opts[:name] || UUID.generate
      @direction   = opts[:direction] || :bidirectional
      @close_mutex = Mutex.new
      @queue       = Queues.register(@name, @max)
    end

    def queue
      q = @queue
      raise Errors::ChannelClosed unless q
      q
    end


    # Serialization methods

    def marshal_load(ary)
      @closed, @name, @max, @type, @direction = *ary
      @queue = Queues[@name]
      @closed = @queue.nil?
      self
    end

    def marshal_dump
      [@closed, @name, @max, @type, @direction]
    end


    # Sending methods

    def send(object, options={})
      check_direction(:send)
      check_type(object)

      push = Push.new(object, options)
      queue.push(push)

      return push if options[:deferred]

      push.wait
    end
    alias :push :send
    alias :<<   :send

    def push?; queue.push?; end
    alias :send? :push?


    # Receiving methods

    def receive(options={})
      check_direction(:receive)

      pop = Pop.new(options)
      queue.pop(pop)

      return pop if options[:deferred]

      ok = pop.wait
      [pop.object, ok]
    end
    alias :pop  :receive

    def pop?; queue.pop?; end
    alias :receive? :pop?


    # Closing methods

    def close
      @close_mutex.synchronize do
        raise Errors::ChannelClosed if @closed
        @closed = true
        @queue.close
        @queue = nil
        Queues.delete(@name)
      end
    end
    def closed?; @closed; end
    def open?;   !@closed;   end

    def remove_operations(operations)
      # ugly, but it overcomes the race condition without synchronization
      # since instance variable access is atomic.
      q = @queue
      q.remove_operations(operations) if q
    end

    def as_send_only
      as_direction_only(:send)
    end

    def as_receive_only
      as_direction_only(:receive)
    end


  private

    def as_direction_only(direction)
      @close_mutex.synchronize do
        raise Errors::ChannelClosed if @closed
        channel!(@type, @max, :name => @name, :direction => direction)
      end
    end

    def check_type(object)
      raise Errors::InvalidType unless object.is_a?(@type)
    end

    def check_direction(direction)
      return if @direction == :bidirectional
      raise Errors::InvalidDirection if @direction != direction
    end

  end
end
