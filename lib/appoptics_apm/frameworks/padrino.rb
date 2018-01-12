# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module PadrinoInst
    module Routing
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :dispatch!, ::Padrino::Routing)
      end

      def dispatch_with_appoptics

        ::AppOpticsAPM::API.log_entry('padrino', {})

        result = dispatch_without_appoptics

        # Report Controller/Action and Transaction as best possible
        report_kvs = {}
        controller = (request.controller && !request.controller.empty?) ? request.controller : nil
        report_kvs[:Controller] = controller || self.class
        report_kvs[:Action] = request.route_obj ? request.route_obj.path : request.action
        env['appoptics_apm.controller'] = report_kvs[:Controller]
        env['appoptics_apm.action']     = report_kvs[:Action]

        result
      ensure
        ::AppOpticsAPM::API.log_exit('padrino', report_kvs)
      end
    end
  end
end

if defined?(::Padrino)
  # This instrumentation is a superset of the Sinatra instrumentation similar
  # to how Padrino is a superset of Sinatra itself.
  ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting Padrino' if AppOpticsAPM::Config[:verbose]

  require 'appoptics_apm/frameworks/padrino/templates'

  Padrino.after_load do
    ::AppOpticsAPM.logger = ::Padrino.logger if ::Padrino.respond_to?(:logger)
    ::AppOpticsAPM::Inst.load_instrumentation

    ::AppOpticsAPM::Util.send_include(::Padrino::Routing::InstanceMethods, ::AppOpticsAPM::PadrinoInst::Routing)
    if defined?(::Padrino::Rendering)
      ::AppOpticsAPM::Util.send_include(::Padrino::Rendering::InstanceMethods, ::AppOpticsAPM::PadrinoInst::Rendering)
    end

    # Report __Init after fork when in Heroku
    AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
  end
end
