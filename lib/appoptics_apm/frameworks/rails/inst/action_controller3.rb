# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v3
    #
    module ActionController
      include ::AppOpticsAPM::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process, :appoptics
          alias_method_chain :process_action, :appoptics
          alias_method_chain :render, :appoptics
        end
      end

      def process_with_appoptics(*args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => self.action_name,
        }
        request.env['appoptics_apm.controller'] = kvs[:Controller]
        request.env['appoptics_apm.action'] = kvs[:Action]

        trace('rails') do
          process_without_appoptics(*args)
        end
      end

      def process_action_with_appoptics(*args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => action_name,
        }
        request.env['appoptics_apm.controller'] = kvs[:Controller]
        request.env['appoptics_apm.action'] = kvs[:Action]

        return process_action_without_appoptics(*args) unless AppOpticsAPM.tracing?
        begin
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:action_controller][:collect_backtraces]
          AppOpticsAPM::API.log(nil, 'info', kvs)

          process_action_without_appoptics(*args)
        rescue Exception
          kvs[:Status] = 500
          AppOpticsAPM::API.log(nil, 'info', kvs)
          raise
        end
      end
    end
  end
end
