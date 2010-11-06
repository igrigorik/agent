# Channels combine communication—the exchange of a value—with synchronization—guaranteeing
# that two calculations (goroutines) are in a known state.
# - http://golang.org/doc/effective_go.html#channels

module Go
  class Channel
    def initialize(opts = {})
      @state = :active
      @direction = opts.delete(:direction) || :bidirectional
    end

    def send(msg)
      check_direction(:send)


    end
    alias :push :send
    alias :<<   :send

    def receive
      check_direction(:receive)

    end
    alias :pop  :receive

    def close; @state = :closed; end
    def closed?; @state == :closed; end

    private

    def check_direction(direction)
      return if @direction == :bidirectional
      raise InvalidDirection if @direction != direction
    end

    class InvalidDirection < Exception; end
  end
end