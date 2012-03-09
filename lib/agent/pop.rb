module Agent
  class Pop
    attr_reader :uuid, :once, :notifier, :object

    def initialize(options={})
      @object   = nil
      @uuid     = options[:uuid] || Agent::UUID.generate
      @once     = options[:once]
      @notifier = options[:notifier]
      @monitor  = Monitor.new
      @cvar     = @monitor.new_cond
      @received = false
      @closed   = false
    end

    def received?
      @received
    end

    def closed?
      @closed
    end

    def runnable?
      !@once || !@once.performed?
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_while{ !received? && !closed? }
        return received?
      end
    end

    def send
      if @once
        value, error = @once.perform do
          @object = Marshal.load(yield)
          @received = true
          @monitor.synchronize{ @cvar.signal }
          @notifier.notify(self) if @notifier
        end

        return error
      else
        @object = Marshal.load(yield)
        @received = true
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
