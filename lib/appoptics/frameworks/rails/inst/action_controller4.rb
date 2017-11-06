# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v4
    #
    module ActionController
      include ::AppOptics::Inst::RailsBase

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
        request.env['appoptics.transaction'] = "#{kvs[:Controller]}.#{kvs[:Action]}"

        return process_action_without_appoptics(method_name, *args) unless AppOptics.tracing?
        begin
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:action_controller][:collect_backtraces]

          AppOptics::API.log_entry('rails', kvs)

          process_action_without_appoptics(method_name, *args)

        rescue Exception => e
          AppOptics::API.log_exception(nil, e) if log_rails_error?(e)
          raise
        ensure
          AppOptics::API.log_exit('rails')
        end
      end
    end
  end
end

