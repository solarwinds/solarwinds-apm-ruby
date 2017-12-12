# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module PadrinoInst
    module Routing
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_appoptics

        ::AppOptics::API.log_entry('padrino', {})

        result = dispatch_without_appoptics

        # Report Controller/Action and Transaction as best possible
        report_kvs = {}
        controller = (request.controller && !request.controller.empty?) ? request.controller : nil
        report_kvs[:Controller] = controller || self.class
        report_kvs[:Action] = request.route_obj ? request.route_obj.path : request.action
        report_kvs[:Action] && report_kvs[:Action].gsub!(/^\//, '')
        env['appoptics.transaction'] = [report_kvs[:Controller], report_kvs[:Action]].compact.join('.')

        result
      ensure
        ::AppOptics::API.log_exit('padrino', report_kvs)
      end
    end
  end
end

if defined?(::Padrino)
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  ::AppOptics.logger.info '[appoptics/loading] Instrumenting Padrino' if AppOptics::Config[:verbose]

  require 'appoptics/frameworks/padrino/templates'

  Padrino.after_load do
    ::AppOptics.logger = ::Padrino.logger if ::Padrino.respond_to?(:logger)
    ::AppOptics::Inst.load_instrumentation

    ::AppOptics::Util.send_include(::Padrino::Routing::InstanceMethods, ::AppOptics::PadrinoInst::Routing)
    if defined?(::Padrino::Rendering)
      ::AppOptics::Util.send_include(::Padrino::Rendering::InstanceMethods, ::AppOptics::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    AppOptics::API.report_init unless AppOptics.heroku?
  end
end
