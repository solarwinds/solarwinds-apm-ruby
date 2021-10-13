# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
class TyphoeusError < StandardError; end

module AppOpticsAPM
  module Inst
    module TyphoeusRequestOps
      include AppOpticsAPM::TraceContextHeaders

      def run
        unless AppOpticsAPM.tracing?
          add_tracecontext_headers(options[:headers], url)
          return super
        end

        begin
          AppOpticsAPM::API.log_entry(:typhoeus)

          context = AppOpticsAPM::Context.toString

          kvs = {}
          kvs[:Spec] = 'rsc'
          kvs[:IsService] = 1
          kvs[:HTTPMethod] = AppOpticsAPM::Util.upcase(options[:method])

          add_tracecontext_headers(options[:headers], url)
          response = super

          # Re-attach edge unless it's blacklisted
          # or if we don't have a valid X-Trace header
          blacklisted = AppOpticsAPM::API.blacklisted?(url)
          unless blacklisted
            xtrace = response.headers['X-Trace']
            AppOpticsAPM::XTrace.continue_service_context(context, xtrace)
          end

          if response.code == 0
            exception = TyphoeusError.new(response.return_message)
            exception.set_backtrace(AppOpticsAPM::API.backtrace)
            AppOpticsAPM::API.log_exception(:typhoeus, exception)
          end

          kvs[:HTTPStatus] = response.code
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:typhoeus][:collect_backtraces]
          # Conditionally log query params
          uri = URI(response.effective_url)
          kvs[:RemoteURL] = AppOpticsAPM::Config[:typhoeus][:log_args] ? uri.to_s : uri.to_s.split('?').first
          kvs[:Blacklisted] = true if blacklisted

          response
        rescue => e
          AppOpticsAPM::API.log_exception(:typhoeus, e)
          raise e
        ensure
          AppOpticsAPM::API.log_exit(:typhoeus, kvs)
        end
      end
    end

    module TyphoeusHydraRunnable
      include AppOpticsAPM::TraceContextHeaders

      def run
        unless AppOpticsAPM.tracing?
          queued_requests.map do |request|
            add_tracecontext_headers(request.options[:headers], request.base_url)
          end
          return super
        end

        kvs = {}

        kvs[:queued_requests] = queued_requests.count
        kvs[:max_concurrency] = max_concurrency
        kvs[:Async] = 1
        kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

        # FIXME: Until we figure out a strategy to deal with libcurl internal
        # threading and Ethon's use of easy handles, here we just do a simple
        # trace of the hydra run.
        AppOpticsAPM::API.trace(:typhoeus_hydra, kvs) do
          queued_requests.map do |request|
            add_tracecontext_headers(request.options[:headers], request.base_url)
          end

          super
        end
      end
    end

  end
end

if defined?(Typhoeus) && AppOpticsAPM::Config[:typhoeus][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting typhoeus' if AppOpticsAPM::Config[:verbose]

  Typhoeus::Request.prepend(AppOpticsAPM::Inst::TyphoeusRequestOps)
  Typhoeus::Hydra.prepend(AppOpticsAPM::Inst::TyphoeusHydraRunnable)
end
