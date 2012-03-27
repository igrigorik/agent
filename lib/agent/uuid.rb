require 'securerandom'

# Borrowed from Celluloid. Using thread locals instead of extending the base
# Thread class, though.
module Agent
  module UUID
    values = SecureRandom.hex(9).match(/(.{8})(.{4})(.{3})(.{3})/)
    PREFIX = "#{values[1]}_#{values[2]}_4#{values[3]}_8#{values[4]}".freeze
    BLOCK_SIZE = 0x10000

    @counter = 0
    @counter_mutex = Mutex.new

    def self.generate
      thread = Thread.current

      unless thread[:__agent_uuid_limit__]
        @counter_mutex.synchronize do
          block_base = @counter
          @counter += BLOCK_SIZE
          thread[:__agent_uuid_counter__] = block_base
          thread[:__agent_uuid_limit__]   = @counter - 1
        end
      end

      counter = thread[:__agent_uuid_counter__]
      if thread[:__agent_uuid_counter__] >= thread[:__agent_uuid_limit__]
        thread[:__agent_uuid_counter__] = thread[:__agent_uuid_limit__] = nil
      else
        thread[:__agent_uuid_counter__] += 1
      end

      "#{PREFIX}_#{sprintf("%012x", counter)}".freeze
    end
  end
end
