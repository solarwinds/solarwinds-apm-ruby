# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_appoptics(*args, &block)
          context = SolarWindsAPM::Context.toString

          if SolarWindsAPM.tracing?
            report_kvs = {}

            begin
              report_kvs[:Spec] = 'rsc'
              report_kvs[:IsService] = 1
              report_kvs[:RemoteURL] = @uri
              report_kvs[:HTTPMethod] = args[0]
              report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:em_http_request][:collect_backtraces]
            rescue => e
              SolarWindsAPM.logger.debug "[solarwinds_apm/debug] em-http-request KV error: #{e.inspect}"
            end

            context = SolarWindsAPM::API.log_entry('em-http-request', report_kvs)
          end
          client = setup_request_without_appoptics(*args, &block)
          client.req.headers['X-Trace'] = context
          client
        end
      end

      module HttpClient

        def parse_response_header_with_appoptics(*args, &block)
          report_kvs = {}
          tracestring = nil

          begin
            report_kvs[:HTTPStatus] = args[2]
            report_kvs[:Async] = 1
          rescue => e
            SolarWindsAPM.logger.debug "[solarwinds_apm/debug] em-http-request KV error: #{e.inspect}"
          end

          parse_response_header_without_appoptics(*args, &block)

          headers = args[0]
          context = SolarWindsAPM::Context.toString
          trace_id = SolarWindsAPM::TraceString.trace_id(context)

          if headers.is_a?(Hash) && headers.key?('X-Trace')
            tracestring = headers['X-Trace']
          end

          if SolarWindsAPM::TraceString.valid?(tracestring) && SolarWindsAPM.tracing?

            # Assure that we received back a valid X-Trace with the same task_id
            if trace_id == SolarWindsAPM::TraceString.trace_id(tracestring)
              SolarWindsAPM::Context.fromString(tracestring)
            else
              SolarWindsAPM.logger.debug "[solarwinds_apm/em-http] Mismatched returned X-Trace ID : #{tracestring}"
            end
          end
        ensure
          SolarWindsAPM::API.log_exit(:'em-http-request', report_kvs)
        end

      end
    end
  end
end

if defined?(EventMachine::HttpConnection) && defined?(EventMachine::HttpClient) && SolarWindsAPM::Config[:em_http_request][:enabled]
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting em-http-request' if SolarWindsAPM::Config[:verbose]

  class EventMachine::HttpConnection
    include SolarWindsAPM::Inst::EventMachine::HttpConnection

    if method_defined?(:setup_request)
      class_eval 'alias :setup_request_without_appoptics :setup_request'
      class_eval 'alias :setup_request :setup_request_with_appoptics'
    else
      SolarWindsAPM.logger.warn '[solarwinds_apm/loading] Couldn\'t properly instrument em-http-request (:setup_request).  Partial traces may occur.'
    end
  end

  class EventMachine::HttpClient
    include SolarWindsAPM::Inst::EventMachine::HttpClient

    if method_defined?(:parse_response_header)
      class_eval 'alias :parse_response_header_without_appoptics :parse_response_header'
      class_eval 'alias :parse_response_header :parse_response_header_with_appoptics'
    else
      SolarWindsAPM.logger.warn '[solarwinds_apm/loading] Couldn\'t properly instrument em-http-request (:parse_response_header).  Partial traces may occur.'
    end
  end
end
