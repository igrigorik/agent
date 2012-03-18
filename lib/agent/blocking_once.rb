module Agent
  class BlockingOnce < Once
    class Rollback < StandardError; end

    def perform
      @monitor.synchronize do
        # Hold this mutex for the minimum amount of time possible, since mutexes are slow
        return nil, error if @performed

        begin
          return yield, nil
          @performed = true
        rescue Rollback
          return nil, error
        end
      end
    end

    def rollback_error
      @rollback_error ||= Agent::Error.new("rolled back")
    end

  end
end
