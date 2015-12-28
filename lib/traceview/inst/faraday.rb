# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module FaradayConnection
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :run_request, ::Faraday::Connection)
      end

      def run_request_with_traceview(method, url, body, headers, &block)
        # Only send service KVs if we're not using the Net::HTTP adapter
        # Otherwise, the Net::HTTP instrumentation will send the service KVs
        handle_service = !@builder.handlers.include?(Faraday::Adapter::NetHttp) &&
                         !@builder.handlers.include?(Faraday::Adapter::Excon)
        TraceView::API.log_entry('faraday')

        result = run_request_without_traceview(method, url, body, headers, &block)

        kvs = {}
        kvs['Middleware'] = @builder.handlers
        kvs['Backtrace'] = TraceView::API.backtrace if TraceView::Config[:faraday][:collect_backtraces]

        if handle_service
          blacklisted = TraceView::API.blacklisted?(@url_prefix.to_s)
          context = TraceView::Context.toString
          task_id = TraceView::XTrace.task_id(context)

          # Avoid cross host tracing for blacklisted domains
          # Conditionally add the X-Trace header to the outgoing request
          @headers['X-Trace'] = context unless blacklisted

          kvs['IsService'] = 1
          kvs['RemoteProtocol'] = (@url_prefix.scheme == 'https') ? 'HTTPS' : 'HTTP'
          kvs['RemoteHost'] = @url_prefix.host
          kvs['RemotePort'] = @url_prefix.port
          kvs['ServiceArg'] = url
          kvs['HTTPMethod'] = method
          kvs[:HTTPStatus] = result.status
          kvs['Blacklisted'] = true if blacklisted

          # Re-attach net::http edge unless it's blacklisted or if we don't have a
          # valid X-Trace header
          unless blacklisted
            xtrace = result.headers['X-Trace']

            if TraceView::XTrace.valid?(xtrace) && TraceView.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == TraceView::XTrace.task_id(xtrace)
                TraceView::Context.fromString(xtrace)
              else
                TraceView.logger.debug "Mismatched returned X-Trace ID: #{xtrace}"
              end
            end
          end
        end

        TraceView::API.log('faraday', 'info', kvs)
        result
      rescue => e
        TraceView::API.log_exception('faraday', e)
        raise e
      ensure
        TraceView::API.log_exit('faraday')
      end
    end
  end
end

if TraceView::Config[:faraday][:enabled]
  if defined?(::Faraday)
    TraceView.logger.info '[traceview/loading] Instrumenting faraday' if TraceView::Config[:verbose]
    ::TraceView::Util.send_include(::Faraday::Connection, ::TraceView::Inst::FaradayConnection)
  end
end
