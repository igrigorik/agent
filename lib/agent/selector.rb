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

    def timeout(t, &blk)
      s = Agent::Channel.new(name: uuid_channel, :type => TrueClass)
      go(s) { sleep t; s.send true; s.close }
      self.case(s, :receive, &blk)
    end

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

        op, c = nil, nil
        if !@r.empty? || !@w.empty?

          s = Agent::Channel.new(name: uuid_channel, :type => Agent::Notification)
          @w.map {|c| c.register_callback(:send, s) }
          @r.map {|c| c.register_callback(:receive, s) }

          begin
            n = s.receive

            case n.type
              when :send    then @w.map {|c| c.remove_callback(:send, n.chan.name)}
              when :receive then @r.map {|c| c.remove_callback(:receive, n.chan.name)}
            end

            op, c = @cases["#{n.chan.name}-#{n.type}"], n.chan
          rescue Exception => e
            if e.message =~ /deadlock/
              raise Exception.new("Selector deadlock: can't select on channel running in same goroutine")
            else
              raise e
            end
          ensure
            s.close
          end

        end

        op.call(c) if op
      end
    end

    private

      def uuid_channel
        SecureRandom.uuid.gsub('-','_').to_sym
      end

  end
end
