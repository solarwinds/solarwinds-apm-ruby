# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module TyphoeusRequestOps

      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :run, ::Typhoeus::Request::Operations)
      end

      def run_with_appoptics
        blacklisted = AppOptics::API.blacklisted?(url)
        unless AppOptics.tracing?
          context = AppOptics::Context.toString
          options[:headers]['X-Trace'] = context if AppOptics::XTrace.valid?(context) && !blacklisted
          return run_without_appoptics
        end

        begin
          AppOptics::API.log_entry(:typhoeus)

          # Prepare X-Trace header handling
          context = AppOptics::Context.toString
          options[:headers]['X-Trace'] = context unless blacklisted

          response = run_without_appoptics

          if response.code == 0
            AppOptics::API.log(:typhoeus, :error, { :ErrorClass => response.return_code,
                                                    :ErrorMsg => response.return_message })
          end

          kvs = {}
          kvs[:IsService] = 1
          kvs[:HTTPStatus] = response.code
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:typhoeus][:collect_backtraces]

          uri = URI(response.effective_url)

          # Conditionally log query params
          if AppOptics::Config[:typhoeus][:log_args]
            kvs[:RemoteURL] = uri.to_s
          else
            kvs[:RemoteURL] = uri.to_s.split('?').first
          end

          kvs[:HTTPMethod] = ::AppOptics::Util.upcase(options[:method])
          kvs[:Blacklisted] = true if blacklisted

          # Re-attach net::http edge unless it's blacklisted or if we don't have a
          # valid X-Trace header
          unless blacklisted
            xtrace = response.headers['X-Trace']
            AppOptics::XTrace.continue_service_context(context, xtrace)
          end

          AppOptics::API.log_info(:typhoeus, kvs)
          response
        rescue => e
          AppOptics::API.log_exception(:typhoeus, e)
          raise e
        ensure
          AppOptics::API.log_exit(:typhoeus)
        end
      end
    end

    module TyphoeusHydraRunnable
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :run, ::Typhoeus::Hydra)
      end

      def run_with_appoptics
        unless AppOptics.tracing?
          context = AppOptics::Context.toString
          queued_requests.map do |request|
            blacklisted = AppOptics::API.blacklisted?(request.base_url)
            request.options[:headers]['X-Trace'] = context if AppOptics::XTrace.valid?(context) && !blacklisted
          end
          return run_without_appoptics
        end

        kvs = {}

        kvs[:queued_requests] = queued_requests.count
        kvs[:max_concurrency] = max_concurrency
        kvs[:Async] = 1

        # FIXME: Until we figure out a strategy to deal with libcurl internal
        # threading and Ethon's use of easy handles, here we just do a simple
        # trace of the hydra run.
        AppOptics::API.trace(:typhoeus_hydra, kvs) do
          queued_requests.map do |request|
            blacklisted = AppOptics::API.blacklisted?(request.base_url)
            request.options[:headers]['X-Trace'] = AppOptics::Context.toString unless blacklisted
          end

          run_without_appoptics
        end
      end
    end

  end
end

if AppOptics::Config[:typhoeus][:enabled]
  if defined?(::Typhoeus)
    AppOptics.logger.info '[appoptics/loading] Instrumenting typhoeus' if AppOptics::Config[:verbose]
    ::AppOptics::Util.send_include(::Typhoeus::Request::Operations, ::AppOptics::Inst::TyphoeusRequestOps)
    ::AppOptics::Util.send_include(::Typhoeus::Hydra, ::AppOptics::Inst::TyphoeusHydraRunnable)
  end
end
