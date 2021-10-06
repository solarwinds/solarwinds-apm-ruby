# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  class TraceContext

    attr_reader :xtrace, :traceparent, :tracestate, :sw_tracestate, :parent_id, :original_tracestate

    class << self
      def w3c_to_ao_trace(traceparent)
        parts = traceparent.split('-')
        "2B#{parts[1]}00000000#{parts[2]}#{parts[3]}".upcase
      end

      def ao_to_w3c_trace(xtrace)
        "00-#{xtrace[2..33]}-#{xtrace[42..57]}-#{xtrace[-2..-1]}".downcase
      end
    end

    def initialize(traceparent=nil, tracestate=nil)
      return unless traceparent && traceparent.is_a?(String)

      # TODO NH-2303
      #  currently storing xtrace in ao format, change when oboe is ready
      @xtrace = TraceContext.w3c_to_ao_trace(traceparent)
      if XTrace.valid?(@xtrace)
        # a sampled xtrace currently provokes a roll-the-dice in oboe
        # therefore we set all incoming xtrace to sampled
        # regardless if they may be ours or not
        @xtrace = XTrace.set_sampled(@xtrace)
        @traceparent = traceparent
        @original_tracestate = tracestate

        @tracestate = TraceState.validate_fix(tracestate)
        if @tracestate
          @sw_tracestate, @parent_id, sampled = TraceState.sw_tracestate(@tracestate)
          @xtrace = XTrace.unset_sampled(@xtrace) if sampled == false
        end
      else
        @xtrace = nil
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
