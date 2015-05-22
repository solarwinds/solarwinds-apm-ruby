# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module RestClientRequest
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :execute, ::RestClient::Request)
      end

      ##
      # execute_with_traceview
      #
      # The wrapper method for RestClient::Request.execute
      #
      def execute_with_traceview & block
        kvs = {}
        kvs['Backtrace'] = TraceView::API.backtrace if TraceView::Config[:rest_client][:collect_backtraces]
        TraceView::API.log_entry("rest-client", kvs)

        # The core rest-client call
        execute_without_traceview(&block)
      rescue => e
        TraceView::API.log_exception('rest-client', e)
        raise e
      ensure
        TraceView::API.log_exit("rest-client")
      end
    end
  end
end

if TraceView::Config[:rest_client][:enabled]
  if defined?(::RestClient)
    TraceView.logger.info '[traceview/loading] Instrumenting rest-client' if TraceView::Config[:verbose]
    ::TraceView::Util.send_include(::RestClient::Request, ::TraceView::Inst::RestClientRequest)
  end
end
