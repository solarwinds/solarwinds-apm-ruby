# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'net/http'

if TraceView::Config[:nethttp][:enabled]

  Net::HTTP.class_eval do
    def request_with_traceview(*args, &block)
      # If we're not tracing, just do a fast return. Since
      # net/http.request calls itself, only trace
      # once the http session has been started.
      if !TraceView.tracing? || !started?
        return request_without_traceview(*args, &block)
      end

      # Avoid cross host tracing for blacklisted domains
      blacklisted = TraceView::API.blacklisted?(addr_port)

      TraceView::API.trace(:'net-http') do
        opts = {}
        context = TraceView::Context.toString()
        task_id = TraceView::XTrace.task_id(context)

        # Collect KVs to report in the info event
        if args.length && args[0]
          req = args[0]

          opts[:IsService] = 1
          opts[:RemoteProtocol] = use_ssl? ? :HTTPS : :HTTP
          opts[:RemoteHost] = addr_port

          # Conditionally log query params
          if TraceView::Config[:nethttp][:log_args]
            opts[:ServiceArg] = req.path
          else
            opts[:ServiceArg] = req.path.split('?').first
          end

          opts[:HTTPMethod] = req.method
          opts[:Blacklisted] = true if blacklisted
          opts[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:nethttp][:collect_backtraces]

          req['X-Trace'] = context unless blacklisted
        end

        begin
          # The actual net::http call
          resp = request_without_traceview(*args, &block)

          # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
          unless blacklisted
            xtrace = resp.get_fields('X-Trace')
            xtrace = xtrace[0] if xtrace && xtrace.is_a?(Array)

            if TraceView::XTrace.valid?(xtrace)

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == TraceView::XTrace.task_id(xtrace)
                TraceView::Context.fromString(xtrace)
              else
                TraceView.logger.debug "Mismatched returned X-Trace ID : #{xtrace} in http.rb"
              end
            end
          end

          opts[:HTTPStatus] = resp.code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? resp.code.to_i) && resp.header["Location"]
            opts[:Location] = resp.header["Location"]
          end

          next resp
        ensure
          # Log the info event with the KVs in opts
          TraceView::API.log(:'net-http', :info, opts)
        end
      end
    end

    alias request_without_traceview request
    alias request request_with_traceview

    TraceView.logger.info '[traceview/loading] Instrumenting net/http' if TraceView::Config[:verbose]
  end
end
