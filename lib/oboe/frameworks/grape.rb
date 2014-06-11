# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

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
          ::Oboe::Util.method_alias(klass, :call, ::Grape::Middleware::Error)
        end

        def call_with_oboe(boom)
          Oboe::API.log_exception(nil, boom) if Oboe.tracing?
          call_without_oboe(boom)
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

