# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module PadrinoInst
    module Rendering
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :render, ::Padrino::Rendering)
      end

      def render_with_traceview(engine, data = nil, options = {}, locals = {}, &block)
        if TraceView.tracing?
          report_kvs = {}

          if data
            report_kvs[:engine] = engine
            report_kvs[:template] = data
          else
            report_kvs[:template] = engine
          end

          if TraceView.tracing_layer_op?('render')
            # For recursive calls to :render (for sub-partials and layouts),
            # use method profiling.
            begin
              report_kvs[:FunctionName] = :render
              report_kvs[:Class]        = :Rendering
              report_kvs[:Module]       = 'Padrino'
              report_kvs[:File]         = __FILE__
              report_kvs[:LineNumber]   = __LINE__
            rescue StandardError => e
              ::TraceView.logger.debug e.message
              ::TraceView.logger.debug e.backtrace.join(', ')
            end

            TraceView::API.profile(report_kvs[:template], report_kvs, false) do
              render_without_traceview(engine, data, options, locals, &block)
            end
          else
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the TraceView::API.trace
            # block method) This removes the need for an info
            # event to send additonal KVs
            ::TraceView::API.log_entry('render', {}, 'render')

            begin
              render_without_traceview(engine, data, options, locals, &block)
            ensure
              ::TraceView::API.log_exit('render', report_kvs)
            end
          end
        else
          render_without_traceview(engine, data, options, locals, &block)
        end
      end
    end
  end
end
