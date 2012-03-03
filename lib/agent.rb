require 'monitor'
require 'thread'
require 'securerandom'

require 'agent/channel'
require 'agent/selector'
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

  def select(&blk)
    s = Agent::Selector.new
    yield s
    s.select
  end
end
