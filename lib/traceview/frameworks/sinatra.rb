# Copyright (c) 2013 AppNeta, Inc.
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
      end

      def handle_exception_with_traceview(boom)
        TraceView::API.log_exception(nil, boom) if TraceView.tracing?
        handle_exception_without_traceview(boom)
      end

      @@rum_xhr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_ajax_header.js.erb')
      @@rum_hdr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_header.js.erb')
      @@rum_ftr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_footer.js.erb')

      def traceview_rum_header
        return unless TraceView::Config.rum_id
        if TraceView.tracing?
          if request.xhr?
            return ERB.new(@@rum_xhr_tmpl).result
          else
            return ERB.new(@@rum_hdr_tmpl).result
          end
        end
      rescue StandardError => e
        TraceView.logger.warn "traceview_rum_header: #{e.message}."
        return ''
      end

      def traceview_rum_footer
        return unless TraceView::Config.rum_id
        if TraceView.tracing?
          # Even though the footer template is named xxxx.erb, there are no ERB tags in it so we'll
          # skip that step for now
          return @@rum_ftr_tmpl
        end
      rescue StandardError => e
        TraceView.logger.warn "traceview_rum_footer: #{e.message}."
        return ''
      end
    end
  end
end

if defined?(::Sinatra)
  require 'traceview/inst/rack'
  require 'traceview/frameworks/sinatra/templates'

  TraceView.logger.info '[traceview/loading] Instrumenting Sinatra' if TraceView::Config[:verbose]

  TraceView::Loading.load_access_key
  TraceView::Inst.load_instrumentation

  ::Sinatra::Base.use TraceView::Rack

  # When in the gem TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(::Padrino) and not (ENV.key?('traceview_GEM_TEST'))
    # Padrino has 'enhanced' routes and rendering so the Sinatra
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    ::TraceView::Util.send_include(::Sinatra::Base,      ::TraceView::Sinatra::Base)
    ::TraceView::Util.send_include(::Sinatra::Templates, ::TraceView::Sinatra::Templates)

    # Report __Init after fork when in Heroku
    TraceView::API.report_init unless TraceView.heroku?
  end
end
