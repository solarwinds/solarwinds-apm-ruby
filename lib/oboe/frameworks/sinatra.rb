# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Sinatra
    module Base
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :dispatch!,         ::Sinatra::Base)
        ::Oboe::Util.method_alias(klass, :handle_exception!, ::Sinatra::Base)
      end

      def dispatch_with_oboe
        if Oboe.tracing?
          report_kvs = {}

          report_kvs[:Controller] = self.class
          report_kvs[:Action] = env['PATH_INFO']

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the Oboe::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::Oboe::API.log_entry('sinatra', {})

          begin
            dispatch_without_oboe
          ensure
            ::Oboe::API.log_exit('sinatra', report_kvs)
          end
        else
          dispatch_without_oboe
        end
      end
      
      def handle_exception_with_oboe(boom)
        Oboe::API.log_exception(nil, boom) if Oboe.tracing?
        handle_exception_without_oboe(boom)
      end
    end
  end
end

if defined?(::Sinatra)
  require 'oboe/inst/rack'
  require 'oboe/frameworks/sinatra/templates'

  Oboe.logger.info "[oboe/loading] Instrumenting Sinatra" if Oboe::Config[:verbose]

  Oboe::Loading.load_access_key
  Oboe::Inst.load_instrumentation

  ::Sinatra::Base.use Oboe::Rack

  # When in TEST environment, we load this instrumentation regardless.
  # Otherwise, only when Padrino isn't around.
  unless defined?(::Padrino) and not (ENV['RACK_ENV'] == "test")
    # Padrino has 'enhanced' routes and rendering so the Sinatra 
    # instrumentation won't work anyways.  Only load for pure Sinatra apps.
    ::Oboe::Util.send_include(::Sinatra::Base,      ::Oboe::Sinatra::Base)
    ::Oboe::Util.send_include(::Sinatra::Templates, ::Oboe::Sinatra::Templates)
      
    # Report __Init after fork when in Heroku
    Oboe::API.report_init unless Oboe.heroku?
  end
end

