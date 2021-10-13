# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'net/http'

if AppOpticsAPM::Config[:nethttp][:enabled]
  module AppOpticsAPM
    module Inst
      module NetHttp
        include AppOpticsAPM::TraceContextHeaders

        # Net::HTTP.class_eval do
        # def request_with_appoptics(*args, &block)
        def request(*args, &block)
          # Avoid cross host tracing for blacklisted domains
          blacklisted = AppOpticsAPM::API.blacklisted?(addr_port)

          # If we're not tracing, just do a fast return. Since
          # net/http.request calls itself, only trace
          # once the http session has been started.
          if !AppOpticsAPM.tracing? || !started?
            if blacklisted # if the other site is blacklisted, we don't want to leak its X-trace
              resp = super
              resp.delete('X-Trace') # if resp['X-Trace']
              return resp
            else
              add_tracecontext_headers(args[0], addr_port)
              return super
            end
          end

          opts = {}
          AppOpticsAPM::API.trace(:'net-http', opts) do
            context = AppOpticsAPM::Context.toString

            # Collect KVs to report in the exit event
            if args.respond_to?(:first) && args.first
              req = args.first

              opts[:Spec] = 'rsc'
              opts[:IsService] = 1
              opts[:RemoteURL] = "#{use_ssl? ? 'https' : 'http'}://#{addr_port}"
              opts[:RemoteURL] << (AppOpticsAPM::Config[:nethttp][:log_args] ? req.path : req.path.split('?').first)
              opts[:HTTPMethod] = req.method
              opts[:Blacklisted] = true if blacklisted
              opts[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:nethttp][:collect_backtraces]

              req['traceparent'] = context unless blacklisted
            end

            begin
              add_tracecontext_headers(args[0], addr_port)
              # The actual net::http call
              resp = super
              # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
              xtrace = resp.get_fields('X-Trace')
              if blacklisted
                # we don't want the x-trace if it is from a blacklisted address
                resp.delete('X-Trace') # if xtrace
              else
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

      end
    end
  end

  Net::HTTP.prepend(AppOpticsAPM::Inst::NetHttp)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting net/http' if AppOpticsAPM::Config[:verbose]
end
