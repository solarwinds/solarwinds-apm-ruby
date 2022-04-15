#sh Copyright (c) SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module SDK
    ##
    #
    # Module to be included in classes with outbound calls
    #
    module TraceContextHeaders

      ##
      # Add w3c tracecontext to headers arg
      #
      # === Argument:
      # * +:headers+   outbound headers, a Hash or other object that can have key/value assigned
      #
      # Internally it uses SolarWindsAPM.trace_context, which is a thread local
      # variable containing verified and processed incoming w3c headers.
      # It gets populated by requests processed by Rack or through the
      # :headers arg in SolarWindsAPM::SDK.start_trace
      #
      # === Example:
      # class OutboundCaller
      #   include SolarWindsAPM::SDK::TraceContextHeaders
      #
      #   # create new headers
      #   def faraday_send
      #     conn = Faraday.new(:url => 'http://example.com')
      #     headers = add_tracecontext_headers
      #     conn.get('/', nil, headers)
      #   end
      #
      #   # add to given headers
      #   def excon_send(headers)
      #     conn = Excon.new('http://example.com')
      #     add_tracecontext_headers(headers)
      #     conn.get(headers: headers)
      #   end
      # end
      #
      # === Returns:
      # * The headers with w3c tracecontext added, also modifies the headers arg if given
      #
      def add_tracecontext_headers(headers = {})
        # make sure the header object can take string keys
        # TODO maybe there is a better check?
        return if headers.is_a?(Array)

        if SolarWindsAPM::Context.isValid
          headers['traceparent'] = SolarWindsAPM::Context.toString
          parent_id_flags = SolarWindsAPM::TraceString.span_id_flags(headers['traceparent'])
          tracestate = SolarWindsAPM.trace_context&.tracestate
          headers['tracestate'] = SolarWindsAPM::TraceState.add_sw_member(tracestate, parent_id_flags)
        else
          # make sure we propagate an incoming trace_context even if we don't trace
          if SolarWindsAPM.trace_context
            headers['traceparent'] = SolarWindsAPM.trace_context.traceparent
            headers['tracestate'] = SolarWindsAPM.trace_context.tracestate
          end
        end
        headers
      end
    end
  end
end
