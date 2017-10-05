# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    module TyphoeusRequestOps

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :run, ::Typhoeus::Request::Operations)
      end

      def run_with_traceview
        blacklisted = TraceView::API.blacklisted?(url)
        unless TraceView.tracing?
          context = TraceView::Context.toString
          options[:headers]['X-Trace'] = context if TraceView::XTrace.valid?(context) && !blacklisted
          return run_without_traceview
        end

        begin
          TraceView::API.log_entry(:typhoeus)

          # Prepare X-Trace header handling
          context = TraceView::Context.toString
          task_id = TraceView::XTrace.task_id(context)
          options[:headers]['X-Trace'] = context unless blacklisted

          response = run_without_traceview

          if response.code == 0
            TraceView::API.log(:typhoeus, :error, { :ErrorClass => response.return_code,
                                                    :ErrorMsg => response.return_message })
          end

          kvs = {}
          kvs[:IsService] = 1
          kvs[:HTTPStatus] = response.code
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:typhoeus][:collect_backtraces]

          uri = URI(response.effective_url)

          # Conditionally log query params
          if TraceView::Config[:typhoeus][:log_args]
            kvs[:RemoteURL] = uri.to_s
          else
            kvs[:RemoteURL] = uri.to_s.split('?').first
          end

          kvs[:HTTPMethod] = ::TraceView::Util.upcase(options[:method])
          kvs[:Blacklisted] = true if blacklisted

          # Re-attach net::http edge unless it's blacklisted or if we don't have a
          # valid X-Trace header
          unless blacklisted
            xtrace = response.headers['X-Trace']

            if xtrace && TraceView::XTrace.valid?(xtrace) && TraceView.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == TraceView::XTrace.task_id(xtrace)
                TraceView::Context.fromString(xtrace)
              else
                TraceView.logger.debug "Mismatched returned X-Trace ID: #{xtrace}"
              end
            end
          end

          TraceView::API.log(:typhoeus, :info, kvs)
          response
        rescue => e
          TraceView::API.log_exception(:typhoeus, e)
          raise e
        ensure
          TraceView::API.log_exit(:typhoeus)
        end
      end
    end

    module TyphoeusHydraRunnable
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :run, ::Typhoeus::Hydra)
      end

      def run_with_traceview
        unless TraceView.tracing?
          context = TraceView::Context.toString
          queued_requests.map do |request|
            blacklisted = TraceView::API.blacklisted?(request.base_url)
            request.options[:headers]['X-Trace'] = context if TraceView::XTrace.valid?(context) && !blacklisted
          end
          return run_without_traceview
        end

        kvs = {}

        kvs[:queued_requests] = queued_requests.count
        kvs[:max_concurrency] = max_concurrency

        # FIXME: Until we figure out a strategy to deal with libcurl internal
        # threading and Ethon's use of easy handles, here we just do a simple
        # trace of the hydra run.
        TraceView::API.trace(:typhoeus_hydra, kvs) do
          queued_requests.map do |request|
            blacklisted = TraceView::API.blacklisted?(request.base_url)
            request.options[:headers]['X-Trace'] = TraceView::Context.toString unless blacklisted
          end

          run_without_traceview
        end
      end
    end

  end
end

if TraceView::Config[:typhoeus][:enabled]
  if defined?(::Typhoeus)
    TraceView.logger.info '[traceview/loading] Instrumenting typhoeus' if TraceView::Config[:verbose]
    ::TraceView::Util.send_include(::Typhoeus::Request::Operations, ::TraceView::Inst::TyphoeusRequestOps)
    ::TraceView::Util.send_include(::Typhoeus::Hydra, ::TraceView::Inst::TyphoeusHydraRunnable)
  end
end
