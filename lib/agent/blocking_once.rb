require "agent/errors"

module Agent
  class BlockingOnce < Once
    def perform
      @mutex.synchronize do
        return nil, error if @performed

        begin
          value      = yield
          @performed = true
          return value, nil
        rescue Errors::Rollback
          return nil, rollback_error
        end
      end
    end

  protected

    def rollback_error
      @rollback_error ||= Error.new("rolled back")
    end

  end
end
