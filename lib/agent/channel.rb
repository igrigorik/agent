require "agent/uuid"
require "agent/push"
require "agent/pop"
require "agent/queues"
require "agent/errors"

module Agent
  def self.channel!(options)
    Agent::Channel.new(options)
  end

  class Channel
    attr_reader :name, :chan, :queue

    class InvalidDirection < Exception; end
    class Untyped < Exception; end
    class InvalidType < Exception; end
    class ChannelClosed < Exception; end

    def initialize(opts = {})
      raise Untyped unless opts[:type]

      # Module includes both classes and modules
      raise InvalidType unless opts[:type].is_a?(Module)

      @state      = :open
      @name       = opts[:name] || Agent::UUID.generate
      @max        = opts[:size] || 0
      @type       = opts[:type]
      @direction  = opts[:direction] || :bidirectional

      @close_mutex = Mutex.new

      @queue = Queues.register(@name, @max)
    end

    def queue
      q = @queue
      raise ChannelClosed unless q
      q
    end


    # Serialization methods

    def marshal_load(ary)
      @state, @name, @max, @type, @direction = *ary
      @queue = Queues.queues[@name]
      @state = :closed unless @queue
      self
    end

    def marshal_dump
      [@state, @name, @max, @type, @direction]
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
        raise ChannelClosed if @state == :closed
        @state = :closed
        @queue.close
        @queue = nil
        Queues.remove(@name)
      end
    end
    def closed?; @state == :closed; end
    def open?;   @state == :open;   end

    def remove_operations(operations)
      # ugly, but it overcomes the race condition without synchronization
      # since instance variable access is atomic.
      q = @queue
      q.remove_operations(operations) if q
    end


  private

    def check_type(object)
      raise InvalidType unless object.is_a?(@type)
    end

    def check_direction(direction)
      return if @direction == :bidirectional
      raise InvalidDirection if @direction != direction
    end

  end
end
