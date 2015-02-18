# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'byebug'

module Oboe
  module Grape
    module API
      def self.extended(klass)
        ::Oboe::Util.class_method_alias(klass, :inherited, ::Grape::API)
      end

      def inherited_with_oboe(subclass)
        inherited_without_oboe(subclass)

        subclass.use ::Oboe::Rack
      end
    end

    module Endpoint
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :run, ::Grape::Endpoint)
      end

      def run_with_oboe(env)
        if Oboe.tracing?
          report_kvs = {}

          report_kvs[:Controller] = self.class
          report_kvs[:Action] = env['PATH_INFO']

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the Oboe::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::Oboe::API.log_entry('grape', {})

          begin
            run_without_oboe(env)
          ensure
            ::Oboe::API.log_exit('grape', report_kvs)
          end
        else
          run_without_oboe(env)
        end
      end
    end

    module Middleware
      module Error
        def self.included(klass)
          ::Oboe::Util.method_alias(klass, :error_response, ::Grape::Middleware::Error)
        end

        def error_response_with_oboe(error = {})
          status, headers, body = error_response_without_oboe(error)

          if Oboe.tracing?
            # Since Grape uses throw/catch and not Exceptions, we manually log
            # the error here.
            kvs = {}
            kvs[:ErrorClass] = 'GrapeError'
            kvs[:ErrorMsg] = error[:message] ? error[:message] : "No message given."
            kvs[:Backtrace] = ::Oboe::API.backtrace if Oboe::Config[:grape][:collect_backtraces]

            ::Oboe::API.log(nil, 'error', kvs)

            # Since calls to error() are handled similar to abort in Grape.  We
            # manually log the rack exit here since the original code won't
            # be returned to
            xtrace = Oboe::API.log_end('rack', :Status => status)

            if headers && Oboe::XTrace.valid?(xtrace)
              unless defined?(JRUBY_VERSION) && Oboe.is_continued_trace?
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
  require 'oboe/inst/rack'

  Oboe.logger.info "[oboe/loading] Instrumenting Grape" if Oboe::Config[:verbose]

  Oboe::Loading.load_access_key
  Oboe::Inst.load_instrumentation

  ::Oboe::Util.send_extend(::Grape::API,               ::Oboe::Grape::API)
  ::Oboe::Util.send_include(::Grape::Endpoint,          ::Oboe::Grape::Endpoint)
  ::Oboe::Util.send_include(::Grape::Middleware::Error, ::Oboe::Grape::Middleware::Error)
end

