# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Sinatra
    module Templates
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :render, ::Sinatra::Templates)
      end

      def render_with_appoptics(engine, data, options = {}, locals = {}, &block)
        if AppOptics.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          if AppOptics.tracing_layer_op?(:render)
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
              ::AppOptics.logger.debug e.message
              ::AppOptics.logger.debug e.backtrace.join(', ')
            end

            AppOptics::API.profile(name, report_kvs, false) do
              render_without_appoptics(engine, data, options, locals, &block)
            end

          else
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the AppOptics::API.trace
            # block method) This removes the need for an info
            # event to send additonal KVs
            ::AppOptics::API.log_entry(:render, {}, :render)

            begin
              render_without_appoptics(engine, data, options, locals, &block)
            ensure
              ::AppOptics::API.log_exit(:render, report_kvs)
            end
          end
        else
          render_without_appoptics(engine, data, options, locals, &block)
        end
      end
    end
  end
end
