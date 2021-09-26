# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  #
  # Module to be included in classes with outbound calls
  # Methods to create and add w3c headers
  #
  module W3CHeaders
    def add_trace_headers(headers, hostname)
      if AppOpticsAPM::Context.isValid && !AppOpticsAPM::API.blacklisted?(hostname)
        headers['traceparent'] = AppOpticsAPM::Context.toString
        parent_id_flags = AppOpticsAPM::XTrace.edge_id_flags(headers['traceparent'])
        headers['tracestate'] = AppOpticsAPM::TraceState.add_kv(headers['tracestate'], parent_id_flags)
      end
    end
  end
end