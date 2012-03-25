require "thread"
require "agent/errors"

module Agent
  def self.go!(*args)
    raise Errors::BlockMissing unless block_given?
    Thread.new(*args){|*a| yield(*a) }
  end
end
