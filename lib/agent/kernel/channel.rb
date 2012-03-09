require "agent/channel"

module Kernel
  def channel!(options)
    Agent.channel!(options)
  end
end
