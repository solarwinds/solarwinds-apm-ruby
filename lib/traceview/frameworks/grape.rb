# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Grape
    module API
      def self.extended(klass)
        ::TraceView::Util.class_method_alias(klass, :inherited, ::Grape::API)
      end

      def inherited_with_traceview(subclass)
        inherited_without_traceview(subclass)

        subclass.use ::TraceView::Rack
      end
    end

    module Endpoint
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :run, ::Grape::Endpoint)
      end

      def run_with_traceview(*args)
        if TraceView.tracing?
          report_kvs = {}

          report_kvs[:Controller] = self.class

          if args.empty?
            report_kvs[:Action] = env['PATH_INFO']
          else
            report_kvs[:Action] = args[0]['PATH_INFO']
          end

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the TraceView::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::TraceView::API.log_entry('grape', {})

          begin
            run_without_traceview(*args)
          ensure
            ::TraceView::API.log_exit('grape', report_kvs)
          end
        else
          run_without_traceview(*args)
        end
      end
    end

    module Middleware
      module Error
        def self.included(klass)
          ::TraceView::Util.method_alias(klass, :error_response, ::Grape::Middleware::Error)
        end

        def error_response_with_traceview(error = {})
          status, headers, body = error_response_without_traceview(error)

          if TraceView.tracing?
            # Since Grape uses throw/catch and not Exceptions, we manually log
            # the error here.
            kvs = {}
            kvs[:ErrorClass] = 'GrapeError'
            kvs[:ErrorMsg] = error[:message] ? error[:message] : "No message given."
            kvs[:Backtrace] = ::TraceView::API.backtrace if TraceView::Config[:grape][:collect_backtraces]

            ::TraceView::API.log(nil, 'error', kvs)

            # Since calls to error() are handled similar to abort in Grape.  We
            # manually log the rack exit here since the original code won't
            # be returned to
            xtrace = TraceView::API.log_end('rack', :Status => status)

            if headers && TraceView::XTrace.valid?(xtrace)
              unless defined?(JRUBY_VERSION) && TraceView.is_continued_trace?
                headers['X-Trace'] = xtrace if headers.is_a?(Hash)
              end
            end
          end

          [status, headers, body]
        end
      end
    end
  end
end

if defined?(::Grape)
  require 'traceview/inst/rack'

  TraceView.logger.info "[traceview/loading] Instrumenting Grape" if TraceView::Config[:verbose]

  TraceView::Loading.load_access_key
  TraceView::Inst.load_instrumentation

  ::TraceView::Util.send_extend(::Grape::API,               ::TraceView::Grape::API)
  ::TraceView::Util.send_include(::Grape::Endpoint,          ::TraceView::Grape::Endpoint)
  ::TraceView::Util.send_include(::Grape::Middleware::Error, ::TraceView::Grape::Middleware::Error)
end

