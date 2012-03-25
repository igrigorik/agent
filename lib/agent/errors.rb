module Agent
  module Errors
    class BlockMissing < Exception; end
    class ChannelClosed < Exception; end
    class InvalidDirection < Exception; end
    class Untyped < Exception; end
    class InvalidType < Exception; end
    class Rollback < Exception; end
    class InvalidQueueSize < Exception; end
    class NotImplementedError < Exception; end
    class DefaultCaseAlreadyDefinedError < Exception; end
    class NegativeWaitGroupCount < Exception; end
  end
end
