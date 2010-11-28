module Agent
  class Selector
    attr_reader :cases

    def initialize
      @cases = []
      @immediate = nil
      @default = nil
    end

    def default(&blk); @default = blk; end

    def case(c, op, &blk)
      condition = c.__send__("#{op}?")

      @immediate ||= blk if condition
      @cases.push blk if blk
    end

    def select
      if @immediate
        @immediate.call
      elsif !@default.nil?
        @default.call
      else
        # IO.select
      end
    end
  end
end
