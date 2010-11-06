# Channels combine communication—the exchange of a value—with synchronization—guaranteeing
# that two calculations (goroutines) are in a known state.
# - http://golang.org/doc/effective_go.html#channels

module Go
  class Channel
    def initialize(opts = {})
      @state      = :active
      @type       = opts.delete(:type)
      @direction  = opts.delete(:direction) || :bidirectional

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
    class Untyped < Exception; end
    class InvalidType < Exception; end
  end
end