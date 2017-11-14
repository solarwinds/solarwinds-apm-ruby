# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module FaradayConnection
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :run_request, ::Faraday::Connection)
      end

      def run_request_with_appoptics(method, url, body, headers, &block)
        unless AppOptics.tracing?
          xtrace = AppOptics::Context.toString
          @headers['X-Trace'] = xtrace if AppOptics::XTrace.valid?(xtrace) && !AppOptics::API.blacklisted?(@url_prefix.to_s)
          return run_request_without_appoptics(method, url, body, headers, &block)
        end

        begin
          AppOptics::API.log_entry(:faraday)

          xtrace = AppOptics::Context.toString
          @headers['X-Trace'] = xtrace if AppOptics::XTrace.valid?(xtrace) && !AppOptics::API.blacklisted?(@url_prefix.to_s)
          result = run_request_without_appoptics(method, url, body, headers, &block)

          kvs = {}
          kvs[:Middleware] = @builder.handlers
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:faraday][:collect_backtraces]

          # Only send service KVs if we're not using the Net::HTTP adapter
          # Otherwise, the Net::HTTP instrumentation will send the service KVs
          handle_service = !@builder.handlers.include?(Faraday::Adapter::NetHttp) &&
              !@builder.handlers.include?(Faraday::Adapter::Excon)
          if handle_service
            blacklisted = AppOptics::API.blacklisted?(@url_prefix.to_s)
            context = AppOptics::Context.toString
            task_id = AppOptics::XTrace.task_id(context)

            # Avoid cross host tracing for blacklisted domains
            # Conditionally add the X-Trace header to the outgoing request
            @headers['X-Trace'] = context unless blacklisted

            kvs[:IsService] = 1
            kvs[:RemoteProtocol] = (@url_prefix.scheme == 'https') ? 'HTTPS' : 'HTTP'
            kvs[:RemoteHost] = @url_prefix.host
            kvs[:RemotePort] = @url_prefix.port
            kvs[:ServiceArg] = url
            kvs[:HTTPMethod] = method
            kvs[:HTTPStatus] = result.status
            kvs[:Blacklisted] = true if blacklisted

            # Re-attach net::http edge unless it's blacklisted or if we don't have a
            # valid X-Trace header
            unless blacklisted
              xtrace = result.headers['X-Trace']
              AppOptics::XTrace.continue_service_context(context, xtrace)
            end
          end

          AppOptics::API.log(:faraday, :info, kvs)
          result
        rescue => e
          AppOptics::API.log_exception(:faraday, e)
          raise e
        ensure
          AppOptics::API.log_exit(:faraday)
        end
      end
    end
  end
end

if AppOptics::Config[:faraday][:enabled]
  if defined?(::Faraday)
    AppOptics.logger.info '[appoptics/loading] Instrumenting faraday' if AppOptics::Config[:verbose]
    ::AppOptics::Util.send_include(::Faraday::Connection, ::AppOptics::Inst::FaradayConnection)
  end
end
