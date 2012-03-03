module Agent
  Notification = Struct.new(:type, :chan)

  class Selector
    attr_reader :cases

    def initialize
      @cases = {}
      @ordered_cases = []
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
      return unless blk

      case_key = "#{c.name}-#{op}"

      # Don't re-add a case for the same op and channel, since the first
      # always wins
      unless @cases[case_key]
        @ordered_cases << [op, c]
        @cases[case_key] = blk
      end
    end

    def select
      op, chan = nil, nil
      if !@ordered_cases.empty?

        s = Agent::Channel.new(name: uuid_channel, :type => Agent::Notification)
        @ordered_cases.each do |op, c|
          c.register_callback(op, s)
          # Don't continue to register callbacks if one already fired
          break if s.receive?
        end

        begin
          begin
            # Don't block if we have a default
            n = s.receive(!@default.nil?)
          rescue ThreadError => e
            # We would only get this error if we had a @default blk
            if e.message =~ /buffer empty/
              op = @default
            else
              # Not due to non-blocking w/ @default, so just re-raise
              raise
            end
          ensure
            @ordered_cases.each do |op, c|
              c.remove_callback(op, s.name)
            end
          end

          if !op
            op, chan = @cases["#{n.chan.name}-#{n.type}"], n.chan
          end
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

      if op
        if chan
          op.call(chan)
        else
          op.call
        end
      end
    end

    private

      def uuid_channel
        UUID.generate.gsub('-','_').to_sym
      end

  end
end