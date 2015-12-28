# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module TraceView
  module PadrinoInst
    module Routing
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_traceview
        if TraceView.tracing?
          report_kvs = {}

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the TraceView::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::TraceView::API.log_entry('padrino', {})

          begin
            r = dispatch_without_traceview

            # Report Controller/Action as best possible
            if request.controller && !request.controller.empty?
              report_kvs[:Controller] = request.controller
            else
              report_kvs[:Controller] = self.class
            end

            report_kvs[:Action] = request.action
            r
          ensure
            ::TraceView::API.log_exit('padrino', report_kvs)
          end
        else
          dispatch_without_traceview
        end
      end
    end
  end
end

if defined?(::Padrino)
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  ::TraceView.logger.info '[traceview/loading] Instrumenting Padrino' if TraceView::Config[:verbose]

  require 'traceview/frameworks/padrino/templates'

  Padrino.after_load do
    ::TraceView.logger = ::Padrino.logger if ::Padrino.respond_to?(:logger)
    ::TraceView::Loading.load_access_key
    ::TraceView::Inst.load_instrumentation

    ::TraceView::Util.send_include(::Padrino::Routing::InstanceMethods, ::TraceView::PadrinoInst::Routing)
    if defined?(::Padrino::Rendering)
      ::TraceView::Util.send_include(::Padrino::Rendering::InstanceMethods, ::TraceView::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    TraceView::API.report_init unless TraceView.heroku?
  end
end
