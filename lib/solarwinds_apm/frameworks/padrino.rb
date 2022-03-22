# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module PadrinoInst
    module Routing
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_sw_apm

        SolarWindsAPM::API.log_entry('padrino', {})
        report_kvs = {}

        result = dispatch_without_sw_apm

        # Report Controller/Action and Transaction as best possible
        controller = (request.controller && !request.controller.empty?) ? request.controller : nil
        report_kvs[:Controller] = controller || self.class
        report_kvs[:Action] = request.route_obj ? request.route_obj.path : request.action
        env['solarwinds_apm.controller'] = report_kvs[:Controller]
        env['solarwinds_apm.action']     = report_kvs[:Action]

        result
      rescue => e
        SolarWindsAPM::API.log_exception('padrino', e)
        raise e
      ensure
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:padrino][:collect_backtraces]
        SolarWindsAPM::API.log_exit('padrino', report_kvs)
      end
    end

    module Rendering
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :render, ::Padrino::Rendering)
      end

      # TODO add test coverage, currently there are no tests for this
      # ____ I'm not sure this gets ever called, Padrino uses Sinatra's render method
      def render_with_sw_apm(engine, data = nil, options = {}, locals = {}, &block)
        if SolarWindsAPM.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          SolarWindsAPM::SDK.trace(:padrino_render, kvs: report_kvs, protect_op: :padrino_render) do
            report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:padrino][:collect_backtraces]
            render_without_sw_apm(engine, data, options, locals, &block)
          end
        else
          render_without_sw_apm(engine, data, options, locals, &block)
        end
      end
    end
  end
end

if defined?(Padrino) && SolarWindsAPM::Config[:padrino][:enabled]
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting Padrino' if SolarWindsAPM::Config[:verbose]

  Padrino.after_load do
    SolarWindsAPM.logger = Padrino.logger if Padrino.respond_to?(:logger)
    SolarWindsAPM::Inst.load_instrumentation

    SolarWindsAPM::Util.send_include(Padrino::Routing::InstanceMethods, SolarWindsAPM::PadrinoInst::Routing)
    if defined?(Padrino::Rendering)
      SolarWindsAPM::Util.send_include(Padrino::Rendering::InstanceMethods, SolarWindsAPM::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    SolarWindsAPM::API.report_init unless SolarWindsAPM.heroku?
  end
end
