# Channels combine communication—the exchange of a value—with synchronization—guaranteeing
# that two calculations (goroutines) are in a known state.
# - http://golang.org/doc/effective_go.html#channels

module Agent
  class Channel
    attr_reader :name, :transport, :chan

    def initialize(opts = {})
      @state      = :active
      @name       = opts[:name]
      @max        = opts[:size] || 1
      @type       = opts[:type]
      @direction  = opts[:direction] || :bidirectional
      @transport  = opts[:transport] || Agent::Transport::Queue

      raise NoName  if @name.nil?
      raise Untyped if @type.nil?

      @chan = @transport.new(@name, @max)
    end

    def marshal_load(ary)
      @state, @name, @type, @direction, @transport = *ary
      @chan = @transport.new(@name)
      self
    end

    def marshal_dump
      [@state, @name, @type, @direction, @transport]
    end

    def send(msg)
      check_direction(:send)
      check_type(msg)

      @chan.send(Marshal.dump(msg))
    end
    alias :push :send
    alias :<<   :send

    def receive
      check_direction(:receive)

      msg = Marshal.load(@chan.receive)
      check_type(msg)

      msg
    end
    alias :pop  :receive

    def closed?; @state == :closed; end
    def close
      @chan.close
      @state = :closed
    end

    private

      def check_type(msg)
        raise InvalidType if !msg.is_a? @type
      end

      def check_direction(direction)
        return if @direction == :bidirectional
        raise InvalidDirection if @direction != direction
      end

      class InvalidDirection < Exception; end
      class NoName < Exception; end
      class Untyped < Exception; end
      class InvalidType < Exception; end
  end
end
