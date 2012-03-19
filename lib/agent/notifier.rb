module Agent
  class Notifier
    attr_reader :payload

    def initialize
      @monitor  = Monitor.new
      @cvar     = @monitor.new_cond
      @notified = false
      @payload  = nil
    end

    def notified?
      @notified
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_until { notified? }
      end
    end

    def notify(payload)
      @monitor.synchronize do
        return Agent::Error.new("already notified") if notified?
        @payload  = payload
        @notified = true
        @cvar.signal
        return nil
      end
    end
  end
end
