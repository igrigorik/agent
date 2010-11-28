module Agent
  class Selector
    attr_reader :cases

    def initialize
      @cases = {}
      @r, @w = [], []
      @immediate = nil
      @default = nil
    end

    def default(&blk); @default = blk; end

    def case(c, op, &blk)
      raise "invalid case, must be a channel" if !c.is_a? Agent::Channel

      condition = c.__send__("#{op}?")
      return unless blk

      case op
      when :send    then @w.push c
      when :receive then @r.push c
      end

      @cases["#{c.name}-#{op}"] = blk
      @immediate ||= blk if condition
    end

    def select
      if @immediate
        @immediate.call
      elsif !@default.nil?
        @default.call

      else
        r,w,e = IO.select(@r, @w, nil, @cases.size > 0 ? nil : 0)

        op = if r
          @cases["#{r.first.name}-receive"]
        elsif w
          @cases["#{w.first.name}-send"]
        end

        op.call if op
      end
    end

    private

  end
end