module Agent
  class Push
    class Rollback < Exception; end

    attr_reader :object, :uuid, :blocking_once, :notifier

    def initialize(object, options={})
      @object        = Marshal.dump(object)
      @uuid          = options[:uuid] || Agent::UUID.generate
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
        raise ChannelClosed if @closed
      end
    end

    def receive
      @mutex.synchronize do
        raise ChannelClosed if @closed

        if @blocking_once
          value, error = @blocking_once.perform do
            begin
              yield @object
              @sent = true
              @cvar.signal
              @notifier.notify(self) if @notifier
            rescue Rollback
              raise BlockingOnce::Rollback
            end
          end

          return error
        else
          begin
            yield @object
            @sent = true
            @cvar.signal
            @notifier.notify(self) if @notifier
          rescue Rollback
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
