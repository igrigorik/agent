require 'agent/channel'
require 'agent/transport/queue'

module Kernel
  def go(*args, &blk)
    Thread.new do
      begin
        blk.call(*args)
      rescue Exception => e
        p e
        p e.backtrace
      end
    end
  end
end
