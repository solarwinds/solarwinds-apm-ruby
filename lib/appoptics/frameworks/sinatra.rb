# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Sinatra
    module Base
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :dispatch!,         ::Sinatra::Base)
        ::AppOptics::Util.method_alias(klass, :handle_exception!, ::Sinatra::Base)
      end

      def dispatch_with_appoptics
        if AppOptics.tracing?
          report_kvs = {}

          report_kvs[:Controller] = self.class
          report_kvs[:Action] = env['PATH_INFO']

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the AppOptics::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::AppOptics::API.log_entry('sinatra', {})

          begin
            dispatch_without_appoptics
          ensure
            ::AppOptics::API.log_exit('sinatra', report_kvs)
          end
        else
          dispatch_without_appoptics
        end
      ensure
        env['appoptics.transaction'] = env['sinatra.route'].gsub(/#{env['REQUEST_METHOD']} /, '') if env['sinatra.route']
      end

      def handle_exception_with_appoptics(boom)
        AppOptics::API.log_exception(nil, boom) if AppOptics.tracing?
        handle_exception_without_appoptics(boom)
      end

      def appoptics_rum_header
        AppOptics.logger.warn '[appoptics/warn] Note that appoptics_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :appoptics_rum_header

      def appoptics_rum_footer
        AppOptics.logger.warn '[appoptics/warn] Note that appoptics_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :appoptics_rum_footer
    end
  end
end

if defined?(::Sinatra)
  require 'appoptics/inst/rack'
  require 'appoptics/frameworks/sinatra/templates'

  AppOptics.logger.info '[appoptics/loading] Instrumenting Sinatra' if AppOptics::Config[:verbose]

  AppOptics::Inst.load_instrumentation

  ::Sinatra::Base.use AppOptics::Rack

  # When in the gem TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(::Padrino) && !ENV.key?('APPOPTICS_GEM_TEST')
    # Padrino has 'enhanced' routes and rendering so the Sinatra
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    ::AppOptics::Util.send_include(::Sinatra::Base,      ::AppOptics::Sinatra::Base)
    ::AppOptics::Util.send_include(::Sinatra::Templates, ::AppOptics::Sinatra::Templates)

    # Report __Init after fork when in Heroku
    AppOptics::API.report_init unless AppOptics.heroku?
  end
end
