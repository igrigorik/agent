require "agent/errors"

module Agent
  class Push
    attr_reader :object, :uuid, :blocking_once, :notifier

    def initialize(object, options={})
      @object        = Marshal.dump(object)
      @uuid          = options[:uuid] || UUID.generate
      @blocking_once = options[:blocking_once]
      @notifier      = options[:notifier]
      @mutex         = Mutex.new
      @cvar          = ConditionVariable.new
      @sent          = false
      @closed        = false
    end

    def sent?
      @sent
    end

    def closed?
      @closed
    end

    def wait
      @mutex.synchronize do
        until @sent || @closed
          @cvar.wait(@mutex)
        end
        raise Errors::ChannelClosed if @closed
      end
    end

    def receive
      @mutex.synchronize do
        raise Errors::ChannelClosed if @closed

        if @blocking_once
          value, error = @blocking_once.perform do
            yield @object
            @sent = true
            @cvar.signal
            @notifier.notify(self) if @notifier
          end

          return error
        else
          begin
            yield @object
            @sent = true
            @cvar.signal
            @notifier.notify(self) if @notifier
          rescue Errors::Rollback
          end
        end
      end
    end

    def close
      @mutex.synchronize do
        return if @sent
        @closed = true
        @cvar.broadcast
        @notifier.notify(self) if @notifier
      end
    end

  end
end
