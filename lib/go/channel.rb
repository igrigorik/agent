# Channels combine communication—the exchange of a value—with synchronization—guaranteeing
# that two calculations (goroutines) are in a known state.
# - http://golang.org/doc/effective_go.html#channels

module Go
  class Channel
    attr_reader :name

    def initialize(opts = {})
      @state      = :active
      @name       = opts[:name]
      @type       = opts[:type]
      @direction  = opts[:direction] || :bidirectional
      @transport  = (opts[:transport] || Go::Transport::Queue).new

      raise NoName  if @name.nil?
      raise Untyped if @type.nil?
    end

    def send(msg)
      check_direction(:send)
      check_type(msg)

    end
    alias :push :send
    alias :<<   :send

    def receive
      check_direction(:receive)

      # receive...
      # TODO: msg = Marshall.load(msg)
      # TODO: check_type(msg)
    end
    alias :pop  :receive

    def close; @state = :closed; end
    def closed?; @state == :closed; end

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