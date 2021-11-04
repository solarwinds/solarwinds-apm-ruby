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
          # If we're not tracing, just do a fast return. Since
          # net/http.request calls itself, only trace
          # once the http session has been started.
          if !AppOpticsAPM.tracing? || !started?
            add_tracecontext_headers(args[0])
            return super
          end

          opts = {}
          AppOpticsAPM::API.trace(:'net-http', opts) do
            # Collect KVs to report in the exit event
            if args.respond_to?(:first) && args.first
              req = args.first

              opts[:Spec] = 'rsc'
              opts[:IsService] = 1
              opts[:RemoteURL] = "#{use_ssl? ? 'https' : 'http'}://#{addr_port}"
              opts[:RemoteURL] << (AppOpticsAPM::Config[:nethttp][:log_args] ? req.path : req.path.split('?').first)
              opts[:HTTPMethod] = req.method
              opts[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:nethttp][:collect_backtraces]
            end

            begin
              add_tracecontext_headers(args[0])
              # The actual net::http call
              resp = super

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
