# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM

  class TraceContext

    attr_reader :traceparent, :tracestate, :tracestring, :sw_member_value

    def initialize(headers = {})
      return if headers.nil? || headers.empty?

      # we won't propagate this context if the traceparent is invalid
      traceparent, tracestate = ingest(headers)
      return unless traceparent.is_a?(String) && SolarWindsAPM::TraceString.valid?(traceparent)

      @traceparent = traceparent
      @tracestate = tracestate

      if @tracestate
        @sw_member_value = TraceState.sw_member_value(@tracestate)
        @tracestring = SolarWindsAPM::TraceString.replace_span_id_flags(@traceparent, @sw_member_value)
      end

      @tracestring ||= @traceparent
    end

    # these are event kvs, not headers
    def add_traceinfo(kvs = {})
      kvs['sw.tracestate_parent_id'] = @sw_member_value[0...-3] if @sw_member_value
      kvs['sw.w3c.tracestate'] = @tracestate if @tracestate
      kvs
    end

    private

    def ingest(headers)
      traceparent_key = headers.keys.find do |key|
        key.to_s.downcase =~ /^(http){0,1}[_-]{0,1}traceparent$/
      end

      tracestate_key = headers.keys.find do |key|
        key.to_s.downcase =~ /^(http){0,1}[_-]{0,1}tracestate$/
      end

      return nil, nil unless traceparent_key && tracestate_key

      [headers[traceparent_key], headers[tracestate_key]]
    end

  end
end
