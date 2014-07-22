# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module PadrinoInst
    module Rendering
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :render, ::Padrino::Rendering)
      end

      def render_with_oboe(engine, data=nil, options={}, locals={}, &block)
        unless Oboe.tracing?
          render_without_oboe(engine, data, options, locals, &block)
        else
          report_kvs = {}

          if data
            report_kvs[:engine] = engine
            report_kvs[:template] = data
          else
            report_kvs[:template] = engine
          end

          if Oboe.tracing_layer_op?('render')
            # For recursive calls to :render (for sub-partials and layouts),
            # use method profiling.
            begin
              report_kvs[:FunctionName] = :render
              report_kvs[:Class]        = :Rendering
              report_kvs[:Module]       = 'Padrino'
              report_kvs[:File]         = __FILE__
              report_kvs[:LineNumber]   = __LINE__
            rescue StandardError => e
              ::Oboe.logger.debug e.message
              ::Oboe.logger.debug e.backtrace.join(", ")
            end

            Oboe::API.profile(report_kvs[:template], report_kvs, false) do
              render_without_oboe(engine, data, options, locals, &block)
            end
          else
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the Oboe::API.trace
            # block method) This removes the need for an info
            # event to send additonal KVs
            ::Oboe::API.log_entry('render', {}, 'render')

            begin
              render_without_oboe(engine, data, options, locals, &block)
            ensure
              ::Oboe::API.log_exit('render', report_kvs)
            end
          end
        end
      end
    end
  end
end

