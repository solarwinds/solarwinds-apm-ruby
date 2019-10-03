# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Sinatra
    module Base
      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :dispatch!,         ::Sinatra::Base)
        AppOpticsAPM::Util.method_alias(klass, :handle_exception!, ::Sinatra::Base)
      end

      def dispatch_with_appoptics

        AppOpticsAPM::API.log_entry('sinatra', {})

        response = dispatch_without_appoptics

        # Report Controller/Action and transaction as best possible
        report_kvs = {}
        report_kvs[:Controller] = self.class
        report_kvs[:Action] = env['sinatra.route']
        env['appoptics_apm.controller'] = report_kvs[:Controller]
        env['appoptics_apm.action']     = report_kvs[:Action]

        response
      rescue => e
        AppOpticsAPM::API.log_exception('sinatra', e)
        raise e
      ensure
        report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:sinatra][:collect_backtraces]
        AppOpticsAPM::API.log_exit('sinatra', report_kvs)
      end

      def handle_exception_with_appoptics(boom)
        AppOpticsAPM::API.log_exception(:sinatra, boom)
        handle_exception_without_appoptics(boom)
      end

      def appoptics_rum_header
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Note that appoptics_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :appoptics_rum_header

      def appoptics_rum_footer
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Note that appoptics_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :appoptics_rum_footer
    end

    module Templates
      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :render, ::Sinatra::Templates)
      end

      def render_with_appoptics(engine, data, options = {}, locals = {}, &block)
        if AppOpticsAPM.tracing?
          report_kvs = {}

          report_kvs[:engine] = engine
          report_kvs[:template] = data

          AppOpticsAPM::SDK.trace(:sinatra_render, report_kvs, :sinatra_render) do
            report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:sinatra][:collect_backtraces]
            render_without_appoptics(engine, data, options, locals, &block)
          end
        else
          render_without_appoptics(engine, data, options, locals, &block)
        end
      end
    end
  end
end

if defined?(Sinatra) && AppopticsAPM::Config[:sinatra][:enabled]
  require 'appoptics_apm/inst/rack'

  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting Sinatra' if AppOpticsAPM::Config[:verbose]

  AppOpticsAPM::Inst.load_instrumentation

  Sinatra::Base.use AppOpticsAPM::Rack

  # When in the gem TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(Padrino) && !ENV.key?('APPOPTICS_GEM_TEST')
    # Padrino has 'enhanced' routes and rendering so the Sinatra
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    AppOpticsAPM::Util.send_include(Sinatra::Base,      AppOpticsAPM::Sinatra::Base)
    AppOpticsAPM::Util.send_include(Sinatra::Templates, AppOpticsAPM::Sinatra::Templates)

    # Report __Init after fork when in Heroku
    AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
  end
end
