# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module FaradayConnection
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :run_request, ::Faraday::Connection)
      end

      def run_request_with_appoptics(method, url, body, headers, &block)
        blacklisted = url_blacklisted?
        unless AppOpticsAPM.tracing?
          xtrace = AppOpticsAPM::Context.toString
          @headers['X-Trace'] = xtrace if AppOpticsAPM::XTrace.valid?(xtrace) && !blacklisted
          return run_request_without_appoptics(method, url, body, headers, &block)
        end

        begin
          AppOpticsAPM::API.log_entry(:faraday)

          xtrace = AppOpticsAPM::Context.toString
          @headers['X-Trace'] = xtrace if AppOpticsAPM::XTrace.valid?(xtrace) && !blacklisted
          result = run_request_without_appoptics(method, url, body, headers, &block)

          kvs = {}
          kvs[:Middleware] = @builder.handlers
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:faraday][:collect_backtraces]

          # Only send service KVs if we're not using the Net::HTTP adapter
          # Otherwise, the Net::HTTP instrumentation will send the service KVs
          handle_service = !@builder.handlers.include?(Faraday::Adapter::NetHttp) &&
              !@builder.handlers.include?(Faraday::Adapter::Excon)
          if handle_service
            context = AppOpticsAPM::Context.toString
            task_id = AppOpticsAPM::XTrace.task_id(context)

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
              AppOpticsAPM::XTrace.continue_service_context(context, xtrace)
            end
          end

          AppOpticsAPM::API.log(:faraday, :info, kvs)
          result
        rescue => e
          AppOpticsAPM::API.log_exception(:faraday, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:faraday)
        end
      end

      private

      def url_blacklisted?
        url = @url_prefix ? @url_prefix.to_s : @host
        AppOpticsAPM::API.blacklisted?(url)
      end
    end
  end
end

if AppOpticsAPM::Config[:faraday][:enabled]
  if defined?(::Faraday)
    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting faraday' if AppOpticsAPM::Config[:verbose]
    ::AppOpticsAPM::Util.send_include(::Faraday::Connection, ::AppOpticsAPM::Inst::FaradayConnection)
  end
end
