module Agent

  Notification = Struct.new(:type, :chan)

  class Selector
    attr_reader :cases

    def initialize
      @cases = {}
      @r, @w = [], []
      @immediate = nil
      @default = nil
    end

    def default(&blk); @default = blk; end

    def case(c, op, &blk)
      raise "invalid case, must be a channel" if !c.is_a? Agent::Channel

      condition = c.__send__("#{op}?")
      return unless blk

      case op
        when :send    then @w.push c
        when :receive then @r.push c
      end

      @cases["#{c.name}-#{op}"] = blk
      @immediate ||= blk if condition
    end

    def select
      if @immediate
        @immediate.call
      elsif !@default.nil?
        @default.call
      else

        op = nil
        begin
          if !@r.empty? || !@w.empty?

            # XXX: naming
            # XXX: unregister
            s = Agent::Channel.new(name: 'rand', :type => Agent::Notification)
            @w.map {|c| c.register_callback(:send, s)}
            @r.map {|c| c.register_callback(:receive, s)}

            n = s.receive
            s.close

            op = @cases["#{n.chan.name}-#{n.type}"]

          end
        rescue Exception => e
          p e
          p e.backtrace
        end

        op.call if op

      end
    end

  end
end
