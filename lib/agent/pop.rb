module Agent
  class Pop
    class Rollback < Exception; end

    attr_reader :uuid, :blocking_once, :notifier, :object

    def initialize(options={})
      @object        = nil
      @uuid          = options[:uuid] || Agent::UUID.generate
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
        until received? || closed?
          @cvar.wait(@mutex)
        end
        return received?
      end
    end

    def send
      @mutex.synchronize do
        raise ChannelClosed if @closed

        if @blocking_once
          value, error = @blocking_once.perform do
            begin
              @object = Marshal.load(yield)
              @received = true
              @cvar.signal
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
            @cvar.signal
            @notifier.notify(self) if @notifier
          rescue Rollback
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
