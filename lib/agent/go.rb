require "thread"
require "agent/errors"

module Agent
  def self.go!(*args, &blk)
    raise BlockMissing unless blk
    Thread.new(*args, &blk)
  end
end
