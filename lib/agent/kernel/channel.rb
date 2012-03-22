require "agent/channel"

module Kernel
  def channel!(*args)
    Agent.channel!(*args)
  end
end
