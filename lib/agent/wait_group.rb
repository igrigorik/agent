require "agent/errors"

module Agent
  class WaitGroup
    attr_reader :count

    def initialize
      @count   = 0
      @mutex   = Mutex.new
      @cvar    = ConditionVariable.new
    end

    def wait
      @mutex.synchronize do
        while @count > 0
          @cvar.wait(@mutex)
        end
      end
    end

    def add(delta)
      @mutex.synchronize do
        modify_count(delta)
      end
    end

    def done
      @mutex.synchronize do
        modify_count(-1)
      end
    end

  protected

    # Expects to be called inside of the mutex
    def modify_count(delta)
      @count += delta
      raise Errors::NegativeWaitGroupCount if @count < 0
      @cvar.signal if @count == 0
    end

  end
end
