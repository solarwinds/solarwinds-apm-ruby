# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module PadrinoInst
    module Routing
      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_appoptics

        AppOpticsAPM::API.log_entry('padrino', {})
        report_kvs = {}

        result = dispatch_without_appoptics

        # Report Controller/Action and Transaction as best possible
        controller = (request.controller && !request.controller.empty?) ? request.controller : nil
        report_kvs[:Controller] = controller || self.class
        report_kvs[:Action] = request.route_obj ? request.route_obj.path : request.action
        env['appoptics_apm.controller'] = report_kvs[:Controller]
        env['appoptics_apm.action']     = report_kvs[:Action]

        result
      rescue => e
        AppOpticsAPM::API.log_exception('padrino', e)
        raise e
      ensure
        report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:padrino][:collect_backtraces]
        AppOpticsAPM::API.log_exit('padrino', report_kvs)
      end
    end

    module Rendering
      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :render, ::Padrino::Rendering)
      end

      # TODO add test coverage, currently there are no tests for this
      def render_with_appoptics(engine, data = nil, options = {}, locals = {}, &block)
        if AppOpticsAPM.tracing?
          report_kvs = {}

          if data
            report_kvs[:engine] = engine
            report_kvs[:template] = data
          else
            report_kvs[:template] = engine
          end

          if AppOpticsAPM.tracing_layer_op?(:render)
            # For recursive calls to :render (for sub-partials and layouts),
            # use method profiling.
            begin
              report_kvs[:FunctionName] = :render
              report_kvs[:Class]        = :Rendering
              report_kvs[:Module]       = :Padrino
              report_kvs[:File]         = __FILE__
              report_kvs[:LineNumber]   = __LINE__
            rescue StandardError => e
              AppOpticsAPM.logger.debug "[appoptics_apm/padrino] #{e.message}"
              AppOpticsAPM.logger.debug e.backtrace.join(', ')
            end

            AppOpticsAPM::API.profile(report_kvs[:template], report_kvs, false) do
              render_without_appoptics(engine, data, options, locals, &block)
            end
          else
            # Fall back to the raw tracing API so we can pass KVs
            # back on exit (a limitation of the AppOpticsAPM::API.trace
            # block method) This removes the need for an info
            # event to send additonal KVs
            AppOpticsAPM::API.log_entry(:render, {}, :render)

            begin
              render_without_appoptics(engine, data, options, locals, &block)
            ensure
              report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:padrino][:collect_backtraces]
              AppOpticsAPM::API.log_exit(:render, report_kvs)
            end
          end
        else
          render_without_appoptics(engine, data, options, locals, &block)
        end
      end
    end
  end
end

if defined?(Padrino) && AppopticsAPM::Config[:padrino][:enabled]
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting Padrino' if AppOpticsAPM::Config[:verbose]

  Padrino.after_load do
    AppOpticsAPM.logger = Padrino.logger if Padrino.respond_to?(:logger)
    AppOpticsAPM::Inst.load_instrumentation

    AppOpticsAPM::Util.send_include(Padrino::Routing::InstanceMethods, AppOpticsAPM::PadrinoInst::Routing)
    if defined?(Padrino::Rendering)
      AppOpticsAPM::Util.send_include(Padrino::Rendering::InstanceMethods, AppOpticsAPM::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
  end
end
