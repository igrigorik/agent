module Agent
  class WaitGroup
    def initialize
      @count   = 0
      @monitor = Monitor.new
      @cvar    = @monitor.new_cond
    end

    def wait
      @monitor.synchronize do
        @cvar.wait_while{ @count > 0 }
      end
    end

    def add(delta)
      @monitor.synchronize do
        @count += delta
        @count = 0 if @count < 0
        @cvar.signal if @count == 0
      end
    end

    def done
      @monitor.synchronize do
        @count -= 1  if @count > 0
        @cvar.signal if @count == 0
      end
    end
  end
end
