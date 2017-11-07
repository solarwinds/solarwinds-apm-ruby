# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Sinatra
    module Base
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :dispatch!,         ::Sinatra::Base)
        ::TraceView::Util.method_alias(klass, :handle_exception!, ::Sinatra::Base)
      end

      def dispatch_with_traceview
        if TraceView.tracing?
          report_kvs = {}

          report_kvs[:Controller] = self.class
          report_kvs[:Action] = env['PATH_INFO']

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the TraceView::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::TraceView::API.log_entry('sinatra', {})

          begin
            dispatch_without_traceview
          ensure
            ::TraceView::API.log_exit('sinatra', report_kvs)
          end
        else
          dispatch_without_traceview
        end
      ensure
        env['traceview.transaction'] = env['sinatra.route'].gsub(/#{env['REQUEST_METHOD']} /, '').gsub(/[^-.:_\/\w ]/, '_')
      end

      def handle_exception_with_traceview(boom)
        TraceView::API.log_exception(nil, boom) if TraceView.tracing?
        handle_exception_without_traceview(boom)
      end

      def traceview_rum_header
        TraceView.logger.warn '[traceview/warn] Note that traceview_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :traceview_rum_header

      def traceview_rum_footer
        TraceView.logger.warn '[traceview/warn] Note that traceview_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :traceview_rum_footer
    end
  end
end

if defined?(::Sinatra)
  require 'traceview/inst/rack'
  require 'traceview/frameworks/sinatra/templates'

  TraceView.logger.info '[traceview/loading] Instrumenting Sinatra' if TraceView::Config[:verbose]

  TraceView::Inst.load_instrumentation

  ::Sinatra::Base.use TraceView::Rack

  # When in the gem TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(::Padrino) && !ENV.key?('TRACEVIEW_GEM_TEST')
    # Padrino has 'enhanced' routes and rendering so the Sinatra
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    ::TraceView::Util.send_include(::Sinatra::Base,      ::TraceView::Sinatra::Base)
    ::TraceView::Util.send_include(::Sinatra::Templates, ::TraceView::Sinatra::Templates)

    # Report __Init after fork when in Heroku
    TraceView::API.report_init unless TraceView.heroku?
  end
end
