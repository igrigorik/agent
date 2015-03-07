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
    ::Agent::Push::SKIP_MARSHAL_TYPES << ::Agent::Channel

    attr_reader :name, :direction, :type, :max, :queue

    def initialize(*args)
      opts          = args.last.is_a?(Hash) ? args.pop : {}
      @type         = args.shift
      @max          = args.shift  || 0
      @closed       = false
      @name         = opts[:name] || UUID.generate
      @direction    = opts[:direction] || :bidirectional
      @skip_marshal = opts[:skip_marshal]
      @close_mutex  = Mutex.new
      @queue        = Queues.register(@name, @type, @max)
    end


    # Serialization methods

    def marshal_load(ary)
      @closed, @name, @max, @type, @direction = *ary
      @queue = Queues[@name]
      @closed = @queue.nil? || @queue.closed?
      self
    end

    def marshal_dump
      [@closed, @name, @max, @type, @direction]
    end


    # Sending methods

    def send(object, options={})
      check_direction(:send)
      q = queue
      raise Errors::ChannelClosed unless q
      q.push(object, {:skip_marshal => @skip_marshal}.merge(options))
    end
    alias :push :send
    alias :<<   :send

    def push?; queue.push?; end
    alias :send? :push?


    # Receiving methods

    def receive(options={})
      check_direction(:receive)
      q = queue
      return q.pop(options) if q
      pop = Pop.new(options)
      pop.close
      return [pop.object, false]
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
