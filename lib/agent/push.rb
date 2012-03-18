module Agent
  class Push
    class Rollback < Exception; end

    attr_reader :object, :uuid, :blocking_once, :notifier

    def initialize(object, options={})
      @object        = Marshal.dump(object)
      @uuid          = options[:uuid] || Agent::UUID.generate
      @blocking_once = options[:blocking_once]
      @notifier      = options[:notifier]
      @monitor       = Monitor.new
      @cvar          = @monitor.new_cond
      @sent          = false
      @closed        = false
    end

    def sent?
      @sent
    end

    def closed?
      @closed
    end

    def runnable?
      !@blocking_once || !@blocking_once.performed?
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_until { sent? || closed? }
        raise Channel::ChannelClosed if closed?
      end
    end

    def receive
      if @blocking_once
        value, error = @blocking_once.perform do
          begin
            yield @object
            @sent = true
            @monitor.synchronize{ @cvar.signal }
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
          @monitor.synchronize{ @cvar.signal }
          @notifier.notify(self) if @notifier
        rescue Rollback
        end
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
