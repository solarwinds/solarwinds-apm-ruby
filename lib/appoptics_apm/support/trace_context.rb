# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  class TraceContext

    attr_reader :xtrace, :tracestate, :sw_tracestate, :parent_id, :original_tracestate

    def initialize(traceparent=nil, tracestate=nil)
      return unless XTrace.valid?(traceparent)
      # a sampled xtrace currently provokes a roll-the-dice in oboe
      # therefore we set all incoming xtrace to sampled
      # regardless if they may be ours or not
      @xtrace = XTrace.set_sampled(traceparent)
      @original_tracestate = tracestate

      @tracestate = TraceState.validate_fix(tracestate)
      if @tracestate
        @sw_tracestate, @parent_id, sampled = TraceState.sw_tracestate(tracestate)
        @xtrace = XTrace.unset_sampled(@xtrace) if sampled == false
      end
    end

    def add_kvs(kvs = {})
      if @xtrace
        kvs['SWParentID'] = @parent_id if @parent_id
        kvs['W3C_tracestate'] = @original_tracestate if @original_tracestate
      end
      kvs
    end

  end
end
