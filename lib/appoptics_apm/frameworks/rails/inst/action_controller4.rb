# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v4
    #
    module ActionController
      include AppOpticsAPM::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process_action, :appoptics
          alias_method_chain :render, :appoptics
        end
      end

      def process_action_with_appoptics(method_name, *args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => self.action_name,
        }
        request.env['appoptics_apm.controller'] = kvs[:Controller]
        request.env['appoptics_apm.action'] = kvs[:Action]

        return process_action_without_appoptics(method_name, *args) unless AppOpticsAPM.tracing?
        begin
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:action_controller][:collect_backtraces]

          AppOpticsAPM::API.log_entry('rails', kvs)

          process_action_without_appoptics(method_name, *args)

        rescue Exception => e
          AppOpticsAPM::API.log_exception('rails', e) if log_rails_error?(e)
          raise
        ensure
          AppOpticsAPM::API.log_exit('rails')
        end
      end
    end
  end
end

