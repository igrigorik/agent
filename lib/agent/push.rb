module Agent
  class Push
    attr_reader :object, :uuid, :once, :notifier

    def initialize(object, options={})
      @object   = Marshal.dump(object)
      @uuid     = options[:uuid] || Agent::UUID.generate
      @once     = options[:once]
      @notifier = options[:notifier]
      @monitor  = Monitor.new
      @cvar     = @monitor.new_cond
      @sent     = false
      @closed   = false
    end

    def sent?
      @sent
    end

    def closed?
      @closed
    end

    def runnable?
      !@once || !@once.performed?
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_while { !sent? && !closed? }
        raise ChannelClosed if closed?
      end
    end

    def receive
      if @once
        value, error = @once.perform do
          yield @object
          @sent = true
          @monitor.synchronize{ @cvar.signal }
          @notifier.notify(self) if @notifier
        end

        return error
      else
        yield @object
        @sent = true
        @monitor.synchronize{ @cvar.signal }
        @notifier.notify(self) if @notifier
      end
    end

    def close
      @monitor.synchronize do
        @closed = true
        @cvar.broadcast
      end
    end

  end
end
