# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v3
    #
    module ActionController
      include ::AppOptics::Inst::RailsBase

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
        request.env['appoptics.transaction'] = "#{kvs[:Controller]}.#{kvs[:Action]}"

        trace('rails') do
          process_without_appoptics(*args)
        end
      end

      def process_action_with_appoptics(*args)
        kvs = {
            :Controller   => self.class.name,
            :Action       => action_name,
        }
        request.env['appoptics.transaction'] = "#{kvs[:Controller]}.#{kvs[:Action]}"

        return process_action_without_appoptics(*args) unless AppOptics.tracing?
        begin
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:action_controller][:collect_backtraces]
          AppOptics::API.log(nil, 'info', kvs)

          process_action_without_appoptics(*args)
        rescue Exception
          kvs[:Status] = 500
          AppOptics::API.log(nil, 'info', kvs)
          raise
        end
      end
    end
  end
end
