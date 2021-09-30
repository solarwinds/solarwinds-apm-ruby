# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  class TraceContext

    attr_reader :xtrace, :tracestate, :sw_tracestate, :parent_id

    def initialize(traceparent, tracestate)
      return unless XTrace.valid?(traceparent)

      @tracestate = TraceState.validate_fix(tracestate)
      if @tracestate
        @xtrace = traceparent
        @sw_tracestate, @parent_id, sampled = TraceState.sw_tracestate(tracestate)
        if sampled == false
          # this will not sample the request
          @xtrace = XTrace.unset_sampled(@xtrace)
        else
          # a sampled xtrace currently provokes a roll-the-dice in oboe
          # therefore we set all incoming xtrace to sampled
          # regardless if they may be ours or not
          @xtrace = XTrace.set_sampled(@xtrace)
        end
      end
    end

    def add_kvs(kvs = {})
      if @xtrace
        kvs['SWParentID'] = @parent_id || 'unknown'
      end
    end

  end
end
