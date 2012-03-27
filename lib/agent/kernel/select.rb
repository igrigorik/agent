require "agent/selector"

module Kernel
  def select!(&blk)
    Agent.select!(&blk)
  end
end
