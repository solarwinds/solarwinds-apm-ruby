# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'net/http'

if AppOptics::Config[:nethttp][:enabled]

  Net::HTTP.class_eval do
    def request_with_appoptics(*args, &block)
      # Avoid cross host tracing for blacklisted domains
      blacklisted = AppOptics::API.blacklisted?(addr_port)

      # If we're not tracing, just do a fast return. Since
      # net/http.request calls itself, only trace
      # once the http session has been started.
      if !AppOptics.tracing? || !started?
        unless blacklisted
          xtrace = AppOptics::Context.toString
          args[0]['X-Trace'] = xtrace if AppOptics::XTrace.valid?(xtrace)
        end
        return request_without_appoptics(*args, &block)
      end

      AppOptics::API.trace(:'net-http') do
        opts = {}
        context = AppOptics::Context.toString
        task_id = AppOptics::XTrace.task_id(context)

        # Collect KVs to report in the info event
        if args.length && args[0]
          req = args[0]

          opts[:IsService] = 1
          opts[:RemoteProtocol] = use_ssl? ? :HTTPS : :HTTP
          opts[:RemoteHost] = addr_port

          # Conditionally log query params
          if AppOptics::Config[:nethttp][:log_args]
            opts[:ServiceArg] = req.path
          else
            opts[:ServiceArg] = req.path.split('?').first
          end

          opts[:HTTPMethod] = req.method
          opts[:Blacklisted] = true if blacklisted
          opts[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:nethttp][:collect_backtraces]

          req['X-Trace'] = context unless blacklisted
        end

        begin
          # The actual net::http call
          resp = request_without_appoptics(*args, &block)

          # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
          unless blacklisted
            xtrace = resp.get_fields('X-Trace')
            xtrace = xtrace[0] if xtrace && xtrace.is_a?(Array)

            AppOptics::XTrace.continue_service_context(context, xtrace)
          end

          opts[:HTTPStatus] = resp.code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? resp.code.to_i) && resp.header["Location"]
            opts[:Location] = resp.header["Location"]
          end

          next resp
        ensure
          # Log the info event with the KVs in opts
          AppOptics::API.log(:'net-http', :info, opts)
        end
      end
    end

    alias request_without_appoptics request
    alias request request_with_appoptics

    AppOptics.logger.info '[appoptics/loading] Instrumenting net/http' if AppOptics::Config[:verbose]
  end
end
