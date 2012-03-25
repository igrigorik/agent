module Agent
  class Notifier
    attr_reader :payload

    def initialize
      @mutex    = Mutex.new
      @cvar     = ConditionVariable.new
      @notified = false
      @payload  = nil
    end

    def notified?
      @notified
    end

    def wait
      @mutex.synchronize do
        until notified?
          @cvar.wait(@mutex)
        end
      end
    end

    def notify(payload)
      @mutex.synchronize do
        return Error.new("already notified") if notified?
        @payload  = payload
        @notified = true
        @cvar.signal
        return nil
      end
    end
  end
end
