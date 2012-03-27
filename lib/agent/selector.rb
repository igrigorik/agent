require "agent/uuid"
require "agent/push"
require "agent/pop"
require "agent/channel"
require "agent/notifier"
require "agent/errors"

module Agent
  def self.select!
    raise Errors::BlockMissing unless block_given?
    selector = Selector.new
    yield selector
    selector.select
  ensure
    if selector
      selector.close_default_channel
      selector.dequeue_operations
    end
  end

  class Selector
    attr_reader :cases

    Case = Struct.new(:uuid, :channel, :direction, :value, :blk)

    def initialize
      @ordered_cases = []
      @cases         = {}
      @operations    = {}
      @blocking_once = BlockingOnce.new
      @notifier      = Notifier.new
    end

    def default(&blk)
      if @default_case
        raise Errors::DefaultCaseAlreadyDefinedError
      else
        @default_case = self.case(channel!(TrueClass, 1), :receive, &blk)
      end
    end

    def timeout(t, &blk)
      s = channel!(TrueClass, 1)
      go!{ sleep t; s.send(true); s.close }
      add_case(s, :timeout, &blk)
    end

    def case(chan, direction, value=nil, &blk)
      raise "invalid case, must be a channel" unless chan.is_a?(Channel)
      raise Errors::BlockMissing if blk.nil? && direction == :receive
      raise Errors::InvalidDirection if direction != :send && direction != :receive
      add_case(chan, direction, value, &blk)
    end

    def select
      if !@ordered_cases.empty?
        @ordered_cases.each do |cse|
          if cse.direction == :send
            @operations[cse.channel] << cse.channel.send(cse.value, :uuid => cse.uuid,
                                                                    :blocking_once => @blocking_once,
                                                                    :notifier => @notifier,
                                                                    :deferred => true)
          else # :receive || :timeout
            @operations[cse.channel] << cse.channel.receive(:uuid => cse.uuid,
                                                            :blocking_once => @blocking_once,
                                                            :notifier => @notifier,
                                                            :deferred => true)
          end
        end

        if @default_case
          @default_case.channel.send(true, :uuid => @default_case.uuid, :blocking_once => @blocking_once, :notifier => @notifier, :deferred => true)
        end

        @notifier.wait

        execute_case(@notifier.payload)
      end
    end

    def dequeue_operations
      @operations.each do |channel, operations|
        channel.remove_operations(operations)
      end
    end

    def close_default_channel
      @default_case.channel.close if @default_case
    end


  protected

    def add_case(chan, direction, value=nil, &blk)
      uuid = UUID.generate
      cse = Case.new(uuid, chan, direction, value, blk)
      @ordered_cases << cse
      @cases[uuid] = cse
      @operations[chan] = []
      cse
    end

    def execute_case(operation)
      raise Errors::ChannelClosed if operation.closed?

      cse = @cases[operation.uuid]
      blk, direction = cse.blk, cse.direction

      if blk
        if direction == :send || direction == :timeout
          blk.call
        else # :receive
          blk.call(operation.object)
        end
      end
    end

  end
end
