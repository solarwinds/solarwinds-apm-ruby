# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Grape
    module Middleware
      module Base
        def self.included(klass)
          ::Oboe::Util.method_alias(klass, :call!, ::Grape::Middleware::Base)
        end

        def call_with_oboe(env)
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
              puts "Calling without oboe"
              call_without_oboe(env)
            ensure
              ::Oboe::API.log_exit('grape', report_kvs)
            end
          else
            call_without_oboe(env)
          end
        end
      end
    
      module Error
        def self.included(klass)
          ::Oboe::Util.method_alias(klass, :call!, ::Grape::Middleware::Error)
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

  ::Oboe::Util.send_include(::Grape::Middleware::Base,  ::Oboe::Grape::Middleware::Base)
  ::Oboe::Util.send_include(::Grape::Middleware::Error, ::Oboe::Grape::Middleware::Error)
end

