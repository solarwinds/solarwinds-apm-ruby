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
      
      @@rum_xhr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_ajax_header.js.erb')
      @@rum_hdr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_header.js.erb')
      @@rum_ftr_tmpl = File.read(File.dirname(__FILE__) + '/rails/helpers/rum/rum_footer.js.erb')

      def oboe_rum_header
        Oboe.logger.warn "Testing"
        return unless Oboe::Config.rum_id
        if Oboe.tracing?
          if request.xhr?
            return ERB.new(@@rum_xhr_tmpl).result
          else
            return ERB.new(@@rum_hdr_tmpl).result
          end
        end
      rescue Exception => e  
        Oboe.logger.warn "oboe_rum_header: #{e.message}."
        return ""
      end

      def oboe_rum_footer
        return unless Oboe::Config.rum_id
        if Oboe.tracing?
          # Even though the footer template is named xxxx.erb, there are no ERB tags in it so we'll
          # skip that step for now
          return @@rum_ftr_tmpl
        end
      rescue Exception => e
        Oboe.logger.warn "oboe_rum_footer: #{e.message}."
        return ""
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

