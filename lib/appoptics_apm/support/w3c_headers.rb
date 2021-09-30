# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  #
  # Module to be included in classes with outbound calls
  #
  module W3CHeaders
    ##
    #
    # method to add w3c headers to headers arg
    #
    # AppOpticsAPM::trace_context is a thread local variable with incoming
    # w3c headers verified and processed
    #
    # TODO remove hostname are once we remove blacklisting
    #
    def add_trace_headers(headers, hostname)
      if AppOpticsAPM::Context.isValid && !AppOpticsAPM::API.blacklisted?(hostname)
        headers['traceparent'] = AppOpticsAPM::Context.toString
        parent_id_flags = AppOpticsAPM::XTrace.edge_id_flags(headers['traceparent'])
        tracestate = AppOpticsAPM::trace_context&.tracestate
        headers['tracestate'] = AppOpticsAPM::TraceState.add_kv(tracestate, parent_id_flags)
      end
    end
  end
end