# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

#####################################################
# FYI:
# Faraday only adds tracing when it is
# not using an adapter that is instrumented
#
# otherwise we would get two spans for the same call
#####################################################

module AppOpticsAPM
  module Inst
    module FaradayConnection
      include AppOpticsAPM::W3CHeaders

      def run_request(method, url, body, headers, &block)
        remote_call = remote_call?
        unless AppOpticsAPM.tracing?
          if remote_call
            add_trace_headers(@headers, @url_prefix ? @url_prefix.to_s : @host)
          end
          return super(method, url, body, headers, &block)
        end

        begin
          AppOpticsAPM::API.log_entry(:faraday)
          xtrace = nil
          if remote_call
            xtrace = AppOpticsAPM::Context.toString
            add_trace_headers(@headers, @url_prefix ? @url_prefix.to_s : @host)
          end

          result = super(method, url, body, headers, &block)

          kvs = {}

          # this seems the safer condition than trying to identify the
          # faraday version when adapter started to work without arg
          # and handlers don't include the adapter anymore
          if @builder.method(:adapter).parameters.find { |ele| ele[0] == :req }
            kvs[:Middleware] = @builder.handlers
          else
            kvs[:Middleware] = [@builder.adapter] + @builder.handlers
          end
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:faraday][:collect_backtraces]

          # Only send service KVs if we're not using an adapter
          # Otherwise, the adapter instrumentation will send the service KVs
          if remote_call
            kvs.merge!(rsc_kvs(url, method, result))
          end
          # Re-attach edge unless it's blacklisted
          # or if we don't have a valid X-Trace header
          unless url_blacklisted?
            xtrace_new = result.headers['X-Trace']
            AppOpticsAPM::XTrace.continue_service_context(xtrace, xtrace_new)
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
        if @builder.method(:adapter).parameters.find { |ele| ele[0] == :req }
          (@builder.handlers.map(&:name) & APPOPTICS_INSTR_ADAPTERS).count == 0
        else
          ((@builder.handlers.map(&:name) << @builder.adapter.name) & APPOPTICS_INSTR_ADAPTERS).count == 0
        end
      end

      def rsc_kvs(_url, method, result)
        kvs = { :Spec => 'rsc',
                :IsService => 1,
                :HTTPMethod => method.upcase,
                :HTTPStatus => result.status, }
        kvs[:Blacklisted] = true if url_blacklisted?
        kvs[:RemoteURL] = result.env.to_hash[:url].to_s
        kvs[:RemoteURL].split('?').first unless AppOpticsAPM::Config[:faraday][:log_args]

        kvs
      end
    end
  end
end

if defined?(Faraday) && AppOpticsAPM::Config[:faraday][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting faraday' if AppOpticsAPM::Config[:verbose]
  Faraday::Connection.prepend(AppOpticsAPM::Inst::FaradayConnection)

  APPOPTICS_INSTR_ADAPTERS = ["Faraday::Adapter::NetHttp", "Faraday::Adapter::Excon", "Faraday::Adapter::Typhoeus"]
  APPOPTICS_INSTR_ADAPTERS << "Faraday::Adapter::HTTPClient" if defined?Faraday::Adapter::HTTPClient
end
