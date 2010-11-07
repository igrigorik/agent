require 'go/channel'
require 'go/transport/queue'

module Kernel
  def go(*args, &blk)
    Thread.new do
      blk.call(*args)
    end
  end
end
