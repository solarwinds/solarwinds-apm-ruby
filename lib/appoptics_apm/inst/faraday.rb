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
        remote_call = remote_call?

        unless AppOpticsAPM.tracing?
          if remote_call && !blacklisted
            xtrace = AppOpticsAPM::Context.toString
            @headers['X-Trace'] = xtrace if AppOpticsAPM::XTrace.valid?(xtrace)
          end
          return run_request_without_appoptics(method, url, body, headers, &block)
        end

        begin
          AppOpticsAPM::API.log_entry(:faraday)

          if remote_call && !blacklisted
            xtrace = AppOpticsAPM::Context.toString
            @headers['X-Trace'] = xtrace if AppOpticsAPM::XTrace.valid?(xtrace)
          end

          result = run_request_without_appoptics(method, url, body, headers, &block)

          # Re-attach edge unless it's blacklisted
          # or if we don't have a valid X-Trace header
          if remote_call && !blacklisted
            xtrace_new = result.headers['X-Trace']
            AppOpticsAPM::XTrace.continue_service_context(xtrace, xtrace_new)
          end
          kvs = {}
          kvs[:Middleware] = @builder.handlers
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:faraday][:collect_backtraces]

          # Only send service KVs if we're not using an adapter
          # Otherwise, the adapter instrumentation will send the service KVs
          if remote_call
            kvs.merge!(rsc_kvs(url, method, result))
            if !blacklisted
              xtrace_new = result.headers['X-Trace']
              AppOpticsAPM::XTrace.continue_service_context(xtrace, xtrace_new)
            end
          end

          result
        rescue => e
          AppOpticsAPM::API.log_exception(:faraday, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:faraday, kvs)
        end
      end

      private

      def url_blacklisted?
        url = @url_prefix ? @url_prefix.to_s : @host
        AppOpticsAPM::API.blacklisted?(url)
      end

      # This is only considered a remote service call if the middleware/adapter is not instrumented
      def remote_call?
          !(@builder.handlers.include?(Faraday::Adapter::NetHttp) ||
            @builder.handlers.include?(Faraday::Adapter::Excon) ||
            @builder.handlers.include?(Faraday::Adapter::HTTPClient) ||
            @builder.handlers.include?(Faraday::Adapter::Typhoeus) )
      end

      def rsc_kvs(url, method, result)
        kvs = { :Spec => 'rsc',
                :IsService => 1,
                :HTTPMethod => method.upcase,
                :HTTPStatus => result.status, }
        kvs[:Blacklisted] = true if url_blacklisted?
        kvs[:RemoteURL] = result.to_hash[:url].to_s
        kvs[:RemoteURL].split('?').first if !AppOpticsAPM::Config[:faraday][:log_args]

        kvs
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
