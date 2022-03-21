# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
class TyphoeusError < StandardError; end

module SolarWindsAPM
  module Inst
    module TyphoeusRequestOps
      include SolarWindsAPM::SDK::TraceContextHeaders

      def run
        unless SolarWindsAPM.tracing?
          add_tracecontext_headers(options[:headers])
          return super
        end

        begin
          SolarWindsAPM::API.log_entry(:typhoeus)

          context = SolarWindsAPM::Context.toString

          kvs = {}
          kvs[:Spec] = 'rsc'
          kvs[:IsService] = 1
          kvs[:HTTPMethod] = SolarWindsAPM::Util.upcase(options[:method])

          add_tracecontext_headers(options[:headers])
          response = super

          if response.code == 0
            exception = TyphoeusError.new(response.return_message)
            exception.set_backtrace(SolarWindsAPM::API.backtrace)
            SolarWindsAPM::API.log_exception(:typhoeus, exception)
          end

          kvs[:HTTPStatus] = response.code
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:typhoeus][:collect_backtraces]
          # Conditionally log query params
          uri = URI(response.effective_url)
          kvs[:RemoteURL] = SolarWindsAPM::Config[:typhoeus][:log_args] ? uri.to_s : uri.to_s.split('?').first

          response
        rescue => e
          SolarWindsAPM::API.log_exception(:typhoeus, e)
          raise e
        ensure
          SolarWindsAPM::API.log_exit(:typhoeus, kvs)
        end
      end
    end

    module TyphoeusHydraRunnable
      include SolarWindsAPM::SDK::TraceContextHeaders

      def run
        unless SolarWindsAPM.tracing?
          queued_requests.map do |request|
            add_tracecontext_headers(request.options[:headers])
          end
          return super
        end

        kvs = {}

        kvs[:queued_requests] = queued_requests.count
        kvs[:max_concurrency] = max_concurrency
        kvs[:Async] = 1
        kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:typhoeus][:collect_backtraces]

        # FIXME: Until we figure out a strategy to deal with libcurl internal
        # threading and Ethon's use of easy handles, here we just do a simple
        # trace of the hydra run.
        SolarWindsAPM::SDK.trace(:typhoeus_hydra, kvs: kvs) do
          queued_requests.map do |request|
            add_tracecontext_headers(request.options[:headers])
          end

          super
        end
      end
    end

  end
end

if defined?(Typhoeus) && SolarWindsAPM::Config[:typhoeus][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting typhoeus' if SolarWindsAPM::Config[:verbose]

  Typhoeus::Request.prepend(SolarWindsAPM::Inst::TyphoeusRequestOps)
  Typhoeus::Hydra.prepend(SolarWindsAPM::Inst::TyphoeusHydraRunnable)
end
