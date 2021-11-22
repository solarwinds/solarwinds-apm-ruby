# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  #
  # Module to be included in classes with outbound calls
  #
  module TraceContextHeaders
    ##
    #
    # method to add w3c headers to headers arg
    #
    # AppOpticsAPM::trace_context is a thread local variable with incoming
    # w3c headers verified and processed
    #
    def add_tracecontext_headers(headers)
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
    end
  end
end
