module Agent
  class Once
    def initialize
      @mutex     = Mutex.new
      @performed = false
    end

    def perform
      # optimium path
      return nil, error if @performed

      # slow path
      @mutex.synchronize do
        return nil, error if @performed
        @performed = true
      end

      return yield, nil
    end

    def performed?
      @performed
    end

  protected

    def error
      @error ||= Error.new("already performed")
    end

  end
end
