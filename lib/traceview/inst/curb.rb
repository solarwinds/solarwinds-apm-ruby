# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module CurlEasy
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :perform, ::Curl::Easy)
      end

      def traceview_collect
        kvs = {}
        kvs['IsService'] = 1

        # Conditionally log query args
        if TraceView::Config[:curb][:log_args]
          kvs[:RemoteURL] = url
        else
          kvs[:RemoteURL] = url.split('?').first
        end

        # kvs['HTTPMethod'] = ::TraceView::Util.upcase(params[:method])
        kvs['Backtrace'] = TraceView::API.backtrace if TraceView::Config[:curb][:collect_backtraces]
        kvs
      rescue => e
        TraceView.logger.debug "[traceview/debug] Error capturing curb KVs: #{e.message}"
        TraceView.logger.debug e.backtrace.join('\n') if ::TraceView::Config[:verbose]
      end

      def perform_with_traceview
        # If we're not tracing, just do a fast return.
        return perform_without_traceview if !TraceView.tracing?

        begin
          response_context = nil

          # Avoid cross host tracing for blacklisted domains
          blacklisted = TraceView::API.blacklisted?(URI(url).hostname)

          req_context = TraceView::Context.toString()
          self.headers['X-Trace'] = req_context unless blacklisted

          kvs = traceview_collect
          kvs['Blacklisted'] = true if blacklisted

          TraceView::API.log_entry('curb', kvs)
          kvs.clear

          # The core curb call
          response = perform_without_traceview

          if response
            response_context = headers['X-Trace']
            kvs['HTTPStatus'] = response_code

            # If we get a redirect, report the location header
            if ((300..308).to_a.include? response_code) && headers.key?("Location")
              kvs["Location"] = headers["Location"]
            end

            if response_context && !blacklisted
              TraceView::XTrace.continue_service_context(req_context, response_context)
            end
          else
            # The call returned false; error
            require 'byebug'; debugger
          end

          response
        rescue => e
          TraceView::API.log_exception('curb', e)
          raise e
        ensure
          TraceView::API.log_exit('curb', kvs)
        end
      end
    end
  end
end

if TraceView::Config[:curb][:enabled] && defined?(::Curl::Easy)
  ::TraceView.logger.info '[traceview/loading] Instrumenting curb' if TraceView::Config[:verbose]
  ::TraceView::Util.send_include(::Curl::Easy, ::TraceView::Inst::CurlEasy)
end
