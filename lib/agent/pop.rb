module Agent
  class Pop
    class Rollback < Exception; end

    attr_reader :uuid, :blocking_once, :notifier, :object

    def initialize(options={})
      @object        = nil
      @uuid          = options[:uuid] || Agent::UUID.generate
      @blocking_once = options[:blocking_once]
      @notifier      = options[:notifier]
      @monitor       = Monitor.new
      @cvar          = @monitor.new_cond
      @received      = false
      @closed        = false
    end

    def received?
      @received
    end

    def closed?
      @closed
    end

    def runnable?
      !@blocking_once || !@blocking_once.performed?
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_until{ received? || closed? }
        return received?
      end
    end

    def send
      @monitor.synchronize do
        return if @closed
        if @blocking_once
          value, error = @blocking_once.perform do
            begin
              @object = Marshal.load(yield)
              @received = true
              @monitor.synchronize{ @cvar.signal }
              @notifier.notify(self) if @notifier
            rescue Rollback
              raise BlockingOnce::Rollback
            end
          end

          return error
        else
          begin
            @object = Marshal.load(yield)
            @received = true
            @monitor.synchronize{ @cvar.signal }
            @notifier.notify(self) if @notifier
          rescue Rollback
          end
        end
      end
    end

    def close
      @monitor.synchronize do
        return if @received
        @closed = true
        @cvar.broadcast
        @notifier.notify(self) if @notifier
      end
    end

  end
end
