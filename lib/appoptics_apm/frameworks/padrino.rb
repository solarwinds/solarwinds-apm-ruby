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
        report_kvs[:Action] = request.action
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
      # ____ I'm not sure this gets ever called, Padrino uses Sinatra's render method
      def render_with_appoptics(engine, data = nil, options = {}, locals = {}, &block)
        if AppOpticsAPM.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          AppOpticsAPM::SDK.trace(:padrino_render, report_kvs, :padrino_render) do
            report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:padrino][:collect_backtraces]
            render_without_appoptics(engine, data, options, locals, &block)
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
