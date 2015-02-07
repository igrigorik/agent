require "agent/errors"

module Agent
  class Pop
    attr_reader :uuid, :blocking_once, :notifier, :object

    def initialize(options={})
      @object        = nil
      @uuid          = options[:uuid] || UUID.generate
      @blocking_once = options[:blocking_once]
      @notifier      = options[:notifier]
      @mutex         = Mutex.new
      @cvar          = ConditionVariable.new
      @received      = false
      @closed        = false
    end

    def received?
      @received
    end

    def closed?
      @closed
    end

    def wait
      @mutex.synchronize do
        until @received || @closed
          @cvar.wait(@mutex)
        end
        return received?
      end
    end

    def send
      @mutex.synchronize do
        if @blocking_once
          _, error = @blocking_once.perform do
            @object = yield unless @closed
            @received = true
            @cvar.signal
            @notifier.notify(self) if @notifier
          end

          return error
        else
          begin
            @object = yield unless @closed
            @received = true
            @cvar.signal
            @notifier.notify(self) if @notifier
          rescue Errors::Rollback
          end
        end
      end
    end

    def close
      @mutex.synchronize do
        return if @received
        @closed = true
        @cvar.broadcast
        @notifier.notify(self) if @notifier
      end
    end

  end
end
