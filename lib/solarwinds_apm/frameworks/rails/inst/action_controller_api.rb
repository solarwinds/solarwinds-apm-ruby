# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v5.
    #
    module ActionControllerAPI
      include SolarWindsAPM::Inst::RailsBase

      def process_action(method_name, *args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => self.action_name
        }
        request.env['solarwinds_apm.controller'] = kvs[:Controller]
        request.env['solarwinds_apm.action'] = kvs[:Action]

        return super(method_name, *args) unless SolarWindsAPM.tracing?
        begin
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:action_controller_api][:collect_backtraces]

          SolarWindsAPM::API.log_entry('rails-api', kvs)
          super(method_name, *args)

        rescue Exception => e
          SolarWindsAPM::API.log_exception('rails', e) if log_rails_error?(e)
          raise
        ensure
          SolarWindsAPM::API.log_exit('rails-api')
        end
      end

      #
      # render
      #
      # Our render wrapper that calls 'trace', which will log if we are tracing
      #
      def render(*args, &blk)
        trace('actionview') do
          super(*args, &blk)
        end
      end
    end
  end
end
