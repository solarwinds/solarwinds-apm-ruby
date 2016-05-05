# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_traceview(*args, &block)
          report_kvs = {}
          context = TraceView::Context.toString
          blacklisted = TraceView::API.blacklisted?(@uri)

          begin
            report_kvs[:IsService] = 1
            report_kvs[:RemoteURL] = @uri
            report_kvs[:HTTPMethod] = args[0]
            report_kvs[:Blacklisted] = true if blacklisted

            if TraceView::Config[:em_http_request][:collect_backtraces]
              report_kvs[:Backtrace] = TraceView::API.backtrace
            end
          rescue => e
            TraceView.logger.debug "[traceview/debug] em-http-request KV error: #{e.inspect}"
          end

          ::TraceView::API.log_entry(:'em-http-request', report_kvs)
          client = setup_request_without_traceview(*args, &block)
          client.req.headers['X-Trace'] = context unless blacklisted
          client
        end
      end

      module HttpClient
        def parse_response_header_with_traceview(*args, &block)
          report_kvs = {}
          xtrace = nil
          blacklisted = TraceView::API.blacklisted?(@uri)

          begin
            report_kvs[:HTTPStatus] = args[2]
            report_kvs[:Async] = 1
          rescue => e
            TraceView.logger.debug "[traceview/debug] em-http-request KV error: #{e.inspect}"
          end

          parse_response_header_without_traceview(*args, &block)

          unless blacklisted
            headers = args[0]
            context = TraceView::Context.toString
            task_id = TraceView::XTrace.task_id(context)

            if headers.is_a?(Hash) && headers.key?('X-Trace')
              xtrace = headers['X-Trace']
            end

            if TraceView::XTrace.valid?(xtrace) && TraceView.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == TraceView::XTrace.task_id(xtrace)
                TraceView::Context.fromString(xtrace)
              else
                TraceView.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
              end
            end

          end

          ::TraceView::API.log_exit(:'em-http-request', report_kvs)
        end
      end
    end
  end
end

if RUBY_VERSION >= '1.9'
  if defined?(::EventMachine::HttpConnection) && defined?(::EventMachine::HttpClient) && TraceView::Config[:em_http_request][:enabled]
    TraceView.logger.info '[traceview/loading] Instrumenting em-http-request' if TraceView::Config[:verbose]

    class ::EventMachine::HttpConnection
      include TraceView::Inst::EventMachine::HttpConnection

      if method_defined?(:setup_request)
        class_eval 'alias :setup_request_without_traceview :setup_request'
        class_eval 'alias :setup_request :setup_request_with_traceview'
      else
        TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument em-http-request (:setup_request).  Partial traces may occur.'
      end
    end

    class ::EventMachine::HttpClient
      include TraceView::Inst::EventMachine::HttpClient

      if method_defined?(:parse_response_header)
        class_eval 'alias :parse_response_header_without_traceview :parse_response_header'
        class_eval 'alias :parse_response_header :parse_response_header_with_traceview'
      else
        TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument em-http-request (:parse_response_header).  Partial traces may occur.'
      end
    end
  end
end
