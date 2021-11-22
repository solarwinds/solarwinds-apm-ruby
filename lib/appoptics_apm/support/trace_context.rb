# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  class TraceContext

    attr_reader :traceparent, :tracestate, :tracestring, :sw_member_value

    def initialize(traceparent = nil, tracestate = nil)
      # we won't propagate this context if the traceparent is invalid
      return unless traceparent.is_a?(String) && AppOpticsAPM::TraceString.valid?(traceparent)

      @traceparent = traceparent
      @tracestate = tracestate

      if @tracestate
        @sw_member_value = TraceState.sw_member_value(@tracestate)
        @tracestring = AppOpticsAPM::TraceString.replace_span_id_flags(@traceparent, @sw_member_value) if @sw_member_value
      end

      @tracestring ||= @traceparent
    end

    # these are event kvs, not headers
    def add_kvs(kvs = {})
      kvs['sw.parent_id'] = @sw_member_value[0...-3] if @sw_member_value
      kvs['sw.w3c.tracestate'] = @tracestate if @tracestate
      kvs
    end

  end
end
