# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

module Oboe
  module PadrinoInst
    module Routing
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_oboe
        if Oboe.tracing?
          report_kvs = {}

          # Fall back to the raw tracing API so we can pass KVs
          # back on exit (a limitation of the Oboe::API.trace
          # block method) This removes the need for an info
          # event to send additonal KVs
          ::Oboe::API.log_entry('padrino', {})

          begin
            r = dispatch_without_oboe

            # Report Controller/Action as best possible
            if request.controller and not request.controller.empty?
              report_kvs[:Controller] = request.controller
            else
              report_kvs[:Controller] = self.class
            end

            report_kvs[:Action] = request.action
            r
           ensure
            ::Oboe::API.log_exit('padrino', report_kvs)
           end
        else
          dispatch_without_oboe
        end
      end
    end
  end
end

if defined?(::Padrino)
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  ::Oboe.logger.info "[oboe/loading] Instrumenting Padrino" if Oboe::Config[:verbose]

  require 'oboe/frameworks/padrino/templates'

  Padrino.after_load do
    ::Oboe.logger = ::Padrino.logger if ::Padrino.respond_to?(:logger)
    ::Oboe::Loading.load_access_key
    ::Oboe::Inst.load_instrumentation

    ::Oboe::Util.send_include(::Padrino::Routing::InstanceMethods, ::Oboe::PadrinoInst::Routing)
    if defined?(::Padrino::Rendering)
      ::Oboe::Util.send_include(::Padrino::Rendering::InstanceMethods, ::Oboe::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    Oboe::API.report_init unless Oboe.heroku?
  end
end
