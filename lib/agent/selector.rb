require "agent/uuid"
require "agent/push"
require "agent/pop"
require "agent/channel"
require "agent/notifier"
require "agent/errors"

module Agent
  def self.select!
    raise BlockMissing unless block_given?
    selector = Agent::Selector.new
    yield selector
    selector.select
  ensure
    selector && selector.dequeue_unrunnable_operations
  end

  class Selector
    attr_reader :cases

    class DefaultCaseAlreadyDefinedError < Exception; end

    Case = Struct.new(:uuid, :channel, :direction, :value, :blk)

    def initialize
      @ordered_cases = []
      @cases         = {}
      @operations    = {}
      @once          = Once.new
      @notifier      = Notifier.new
    end

    def default(&blk)
      if @default_case
        @default_case.channel.close
        raise DefaultCaseAlreadyDefinedError
      else
        @default_case = self.case(channel!(:type => TrueClass), :receive, &blk)
      end
    end

    def timeout(t, &blk)
      s = channel!(:type => TrueClass)
      go!{ sleep t; s.send(true); s.close }
      self.case(s, :receive, &blk)
    end

    def case(chan, direction, value=nil, &blk)
      raise "invalid case, must be a channel" unless chan.is_a?(Agent::Channel)
      raise BlockMissing unless blk
      uuid = Agent::UUID.generate
      cse = Case.new(uuid, chan, direction, value, blk)
      @ordered_cases << cse
      @cases[uuid] = cse
      @operations[chan] = []
      cse
    end

    def select
      if !@ordered_cases.empty?
        @ordered_cases.each do |cse|
          if cse.direction == :send
            @operations[cse.channel] << cse.channel.send(cse.value, :uuid => cse.uuid,
                                                                    :once => @once,
                                                                    :notifier => @notifier,
                                                                    :deferred => true)
          else # :receive
            @operations[cse.channel] << cse.channel.receive(:uuid => cse.uuid,
                                                            :once => @once,
                                                            :notifier => @notifier,
                                                            :deferred => true)
          end
        end

        if @default_case
          @default_case.channel.send(true, :uuid => @default_case.uuid, :once => @once, :notifier => @notifier, :deferred => true)
        end

        @notifier.wait
        operation = @notifier.payload

        if operation.is_a?(Push)
          @cases[operation.uuid].blk.call
        else # Pop
          @cases[operation.uuid].blk.call(operation.object)
        end

        @default_case.channel.close if @default_case
      end
    end

    def dequeue_unrunnable_operations
      @operations.each do |channel, operations|
        channel.remove_operations(operations)
      end
    end

  end
end
