#sh Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
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
      # * +:headers+   (Hash) outbound headers
      #
      # Internally it uses AppOpticsAPM.trace_context, which is a thread local
      # variable containing verified and processed incoming w3c headers.
      # It gets populated by requests processed by Rack or through the
      # :headers arg in AppOpticsAPM::SDK.start_trace
      #
      # === Example:
      # class OutboundCaller
      #   include AppOpticsAPM::SDK::TraceContextHeaders
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
        if AppOpticsAPM::Context.isValid
          headers['traceparent'] = AppOpticsAPM::Context.toString
          parent_id_flags = AppOpticsAPM::TraceString.span_id_flags(headers['traceparent'])
          tracestate = AppOpticsAPM.trace_context&.tracestate
          headers['tracestate'] = AppOpticsAPM::TraceState.add_sw_member(tracestate, parent_id_flags)
        else
          # make sure we propagate an incoming trace_context even if we don't trace
          if AppOpticsAPM.trace_context
            headers['traceparent'] = AppOpticsAPM.trace_context.traceparent
            headers['tracestate'] = AppOpticsAPM.trace_context.tracestate
          end
        end
        headers
      end
    end
  end
end
