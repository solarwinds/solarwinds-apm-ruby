# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Sinatra
    module Base
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :dispatch!,         ::Sinatra::Base)
        SolarWindsAPM::Util.method_alias(klass, :handle_exception!, ::Sinatra::Base)
      end

      def dispatch_with_sw_apm

        SolarWindsAPM::API.log_entry('sinatra', {})

        response = dispatch_without_sw_apm

        # Report Controller/Action and transaction as best possible
        report_kvs = {}
        report_kvs[:Controller] = self.class
        report_kvs[:Action] = env['sinatra.route']
        env['solarwinds_apm.controller'] = report_kvs[:Controller]
        env['solarwinds_apm.action']     = report_kvs[:Action]

        response
      rescue => e
        SolarWindsAPM::API.log_exception('sinatra', e)
        raise e
      ensure
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:sinatra][:collect_backtraces]
        SolarWindsAPM::API.log_exit('sinatra', report_kvs)
      end

      def handle_exception_with_sw_apm(boom)
        SolarWindsAPM::API.log_exception(:sinatra, boom)
        handle_exception_without_sw_apm(boom)
      end

      def sw_apm_rum_header
        SolarWindsAPM.logger.warn '[solarwinds_apm/warn] Note that sw_apm_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :sw_apm_rum_header

      def sw_apm_rum_footer
        SolarWindsAPM.logger.warn '[solarwinds_apm/warn] Note that sw_apm_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :sw_apm_rum_footer
    end

    module Templates
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :render, ::Sinatra::Templates)
      end

      def render_with_sw_apm(engine, data, options = {}, locals = {}, &block)
        if SolarWindsAPM.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          SolarWindsAPM::SDK.trace(:sinatra_render, kvs: report_kvs, protect_op: :sinatra_render) do
            report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:sinatra][:collect_backtraces]
            render_without_sw_apm(engine, data, options, locals, &block)
          end
        else
          render_without_sw_apm(engine, data, options, locals, &block)
        end
      end
    end
  end
end

if defined?(Sinatra) && SolarWindsAPM::Config[:sinatra][:enabled]
  require 'solarwinds_apm/inst/rack'

  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting Sinatra' if SolarWindsAPM::Config[:verbose]

  SolarWindsAPM::Inst.load_instrumentation

  Sinatra::Base.use SolarWindsAPM::Rack

  # When in the gem TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(Padrino) && !ENV.key?('SW_APM_GEM_TEST')
    # Padrino has 'enhanced' routes and rendering so the Sinatra
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    SolarWindsAPM::Util.send_include(Sinatra::Base,      SolarWindsAPM::Sinatra::Base)
    SolarWindsAPM::Util.send_include(Sinatra::Templates, SolarWindsAPM::Sinatra::Templates)

    # Report __Init after fork when in Heroku
    SolarWindsAPM::API.report_init unless SolarWindsAPM.heroku?
  end
end
