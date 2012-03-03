# Channels combine communication—the exchange of a value—with synchronization—guaranteeing
# that two calculations (goroutines) are in a known state.
# - http://golang.org/doc/effective_go.html#channels

module Agent
  class Channel
    attr_reader :name, :transport, :chan

    def initialize(opts = {})
      raise InvalidName if !opts[:name].is_a?(Symbol) || opts[:name].nil?
      raise Untyped if opts[:type].nil?

      @state      = :active
      @name       = opts[:name]
      @max        = opts[:size] || 1
      @type       = opts[:type]
      @direction  = opts[:direction] || :bidirectional
      @transport  = opts[:transport] || Agent::Transport::Queue
      @rcb, @wcb  = [], []

      @chan = @transport.new(@name, @max)
    end

    def marshal_load(ary)
      @state, @name, @type, @direction, @transport, @rcb, @wcb = *ary
      @chan = @transport.new(@name)
      self
    end

    def register_callback(type, c)
      case type
      when :receive then @rcb << c
      when :send    then @wcb << c
      end
    end

    def remove_callback(type, name)
      case type
      when :receive then @rcb.delete_if {|c| c.chan.name == name }
      when :send    then @wcb.delete_if {|c| c.chan.name == name }
      end
    end

    def marshal_dump
      [@state, @name, @type, @direction, @transport, @rcb, @wcb]
    end

    def push?; @chan.push?; end
    alias :send? :push?

    def send(msg, nonblock = false)
      check_direction(:send)
      check_type(msg)

      @chan.send(Marshal.dump(msg))
      callback(:receive, @rcb.shift)
    end
    alias :push :send
    alias :<<   :send

    def pop?; @chan.pop?; end
    alias :receive? :pop?

    def receive
      check_direction(:receive)

      msg = Marshal.load(@chan.receive)
      check_type(msg)
      callback(:send, @wcb.shift)

      msg
    end
    alias :pop  :receive

    def closed?; @state == :closed; end
    def close
      @chan.close
      @state = :closed
    end

    private

      def callback(type, c)
        c.send Agent::Notification.new(type, self) if c
      end

      def check_type(msg)
        raise InvalidType if !msg.is_a? @type
      end

      def check_direction(direction)
        return if @direction == :bidirectional
        raise InvalidDirection if @direction != direction
      end

      class InvalidDirection < Exception; end
      class InvalidName < Exception; end
      class Untyped < Exception; end
      class InvalidType < Exception; end
  end
end
