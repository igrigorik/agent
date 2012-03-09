module Agent
  class Error
    def initialize(message)
      @message = message
    end

    def to_s
      @message
    end

    def message?(message)
      @message == message
    end
  end
end
