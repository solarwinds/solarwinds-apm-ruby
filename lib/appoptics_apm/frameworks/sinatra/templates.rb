# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Sinatra
    module Templates
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :render, ::Sinatra::Templates)
      end

      def render_with_appoptics(engine, data, options = {}, locals = {}, &block)
        if AppOpticsAPM.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          if AppOpticsAPM.tracing_layer_op?(:render)
            # For recursive calls to :render (for sub-partials and layouts),
            # use method profiling.
            begin
              name = data
              report_kvs[:FunctionName] = :render
              report_kvs[:Class]        = :Templates
              report_kvs[:Module]       = :'Sinatra::Templates'
              report_kvs[:File]         = __FILE__
              report_kvs[:LineNumber]   = __LINE__
            rescue StandardError => e
              ::AppOpticsAPM.logger.debug e.message
              ::AppOpticsAPM.logger.debug e.backtrace.join(', ')
            end

            AppOpticsAPM::API.profile(name, report_kvs, false) do
              render_without_appoptics(engine, data, options, locals, &block)
            end

          else
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the AppOpticsAPM::API.trace
            # block method) This removes the need for an info
            # event to send additonal KVs
            ::AppOpticsAPM::API.log_entry(:render, {}, :render)

            begin
              render_without_appoptics(engine, data, options, locals, &block)
            ensure
              ::AppOpticsAPM::API.log_exit(:render, report_kvs, :render)
            end
          end
        else
          render_without_appoptics(engine, data, options, locals, &block)
        end
      end
    end
  end
end
