# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Sinatra
    module Templates 
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :render, ::Sinatra::Templates)
      end

      def render_with_oboe(engine, data, options = {}, locals = {}, &block)
        if Oboe.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          if Oboe::Context.tracing_layer_op?('render')
            # For recursive calls to :render (for sub-partials and layouts), 
            # use method profiling.
            begin
              name = data
              report_kvs[:FunctionName] = :render
              report_kvs[:Class]        = :Templates
              report_kvs[:Module]       = 'Sinatra::Templates'
              report_kvs[:File]         = __FILE__
              report_kvs[:LineNumber]   = __LINE__
            rescue StandardError => e
              ::Oboe.logger.debug e.message
              ::Oboe.logger.debug e.backtrace.join(", ")
            end

            Oboe::API.profile(name, report_kvs, false) do
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
        else
          render_without_oboe(engine, data, options, locals, &block)
        end
      end
    end
  end
end

if defined?(::Sinatra::Templates)
  ::Oboe::Util.send_include(::Sinatra::Templates, ::Oboe::Sinatra::Templates)
end
