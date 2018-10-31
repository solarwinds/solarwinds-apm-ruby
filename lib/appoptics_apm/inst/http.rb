# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'net/http'

if AppOpticsAPM::Config[:nethttp][:enabled]

  Net::HTTP.class_eval do
    def request_with_appoptics(*args, &block)
      # Avoid cross host tracing for blacklisted domains
      blacklisted = AppOpticsAPM::API.blacklisted?(addr_port)

      # If we're not tracing, just do a fast return. Since
      # net/http.request calls itself, only trace
      # once the http session has been started.
      if !AppOpticsAPM.tracing? || !started?
        unless blacklisted
          xtrace = AppOpticsAPM::Context.toString
          args[0]['X-Trace'] = xtrace if AppOpticsAPM::XTrace.valid?(xtrace)
        end
        return request_without_appoptics(*args, &block)
      end

      opts = {}
      AppOpticsAPM::API.trace(:'net-http', opts) do
        context = AppOpticsAPM::Context.toString
        # task_id = AppOpticsAPM::XTrace.task_id(context)

        # Collect KVs to report in the info event
        if args.respond_to?(:first) && args.first
          req = args.first

          opts[:Spec] = 'rsc'
          opts[:IsService] = 1
          opts[:RemoteURL] = "#{use_ssl? ? 'https' : 'http'}://#{addr_port}"
          opts[:RemoteURL] << (AppOpticsAPM::Config[:nethttp][:log_args] ? req.path : req.path.split('?').first)
          opts[:HTTPMethod] = req.method
          opts[:Blacklisted] = true if blacklisted
          opts[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:nethttp][:collect_backtraces]

          req['X-Trace'] = context unless blacklisted
        end

        begin
          # The actual net::http call
          resp = request_without_appoptics(*args, &block)

          # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
          unless blacklisted
            xtrace = resp.get_fields('X-Trace')
            xtrace = xtrace[0] if xtrace && xtrace.is_a?(Array)

            AppOpticsAPM::XTrace.continue_service_context(context, xtrace)
          end

          opts[:HTTPStatus] = resp.code

          # If we get a redirect, report the location header
          if ((300..308).to_a.include? resp.code.to_i) && resp.header["Location"]
            opts[:Location] = resp.header["Location"]
          end

          next resp
        end
      end
    end

    alias request_without_appoptics request
    alias request request_with_appoptics

    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting net/http' if AppOpticsAPM::Config[:verbose]
  end
end
