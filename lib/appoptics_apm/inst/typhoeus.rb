# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
class TyphoeusError < StandardError; end

module AppOpticsAPM
  module Inst
    module TyphoeusRequestOps

      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :run, ::Typhoeus::Request::Operations)
      end

      def run_with_appoptics
        blacklisted = AppOpticsAPM::API.blacklisted?(url)
        unless AppOpticsAPM.tracing?
          context = AppOpticsAPM::Context.toString
          options[:headers]['traceparent'] = context if AppOpticsAPM::XTrace.valid?(context) && !blacklisted
          return run_without_appoptics
        end

        begin
          AppOpticsAPM::API.log_entry(:typhoeus)

          # Prepare X-Trace header handling
          context = AppOpticsAPM::Context.toString
          options[:headers]['traceparent'] = context unless blacklisted

          kvs = {}
          kvs[:Spec] = 'rsc'
          kvs[:IsService] = 1
          kvs[:HTTPMethod] = AppOpticsAPM::Util.upcase(options[:method])

          response = run_without_appoptics

          # Re-attach edge unless it's blacklisted
          # or if we don't have a valid X-Trace header
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
      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :run, ::Typhoeus::Hydra)
      end

      def run_with_appoptics
        unless AppOpticsAPM.tracing?
          context = AppOpticsAPM::Context.toString
          queued_requests.map do |request|
            blacklisted = AppOpticsAPM::API.blacklisted?(request.base_url)
            request.options[:headers]['traceparent'] = context if AppOpticsAPM::XTrace.valid?(context) && !blacklisted
          end
          return run_without_appoptics
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
            blacklisted = AppOpticsAPM::API.blacklisted?(request.base_url)
            request.options[:headers]['traceparent'] = AppOpticsAPM::Context.toString unless blacklisted
          end

          run_without_appoptics
        end
      end
    end

  end
end

if defined?(Typhoeus) && AppOpticsAPM::Config[:typhoeus][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting typhoeus' if AppOpticsAPM::Config[:verbose]
  AppOpticsAPM::Util.send_include(Typhoeus::Request::Operations, AppOpticsAPM::Inst::TyphoeusRequestOps)
  AppOpticsAPM::Util.send_include(Typhoeus::Hydra, AppOpticsAPM::Inst::TyphoeusHydraRunnable)
end
