require "agent/go"

module Kernel
  def go!(*args, &blk)
    Agent.go!(*args, &blk)
  end
end
