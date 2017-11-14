# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v2
    #
    module ActionController
      include ::AppOptics::Inst::RailsBase

      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :perform_action)
        ::AppOptics::Util.method_alias(klass, :rescue_action)
        ::AppOptics::Util.method_alias(klass, :process)
        ::AppOptics::Util.method_alias(klass, :render)
      end

      def process_with_appoptics(*args)
        AppOptics::API.log_entry('rails')
        process_without_appoptics(*args)

      rescue Exception => e
        AppOptics::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        AppOptics::API.log_exit('rails')
      end

      def perform_action_with_appoptics(*arguments)
        kvs = {
          :Controller  => @_request.path_parameters['controller'],
          :Action      => @_request.path_parameters['action']
        }
        kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:action_controller][:collect_backtraces]

        AppOptics::API.log(nil, 'info', kvs)
        perform_action_without_appoptics(*arguments)
      end

      def rescue_action_with_appoptics(exn)
        AppOptics::API.log_exception(nil, exn) if log_rails_error?(exn)
        rescue_action_without_appoptics(exn)
      end

      def render_with_appoptics(options = nil, extra_options = {}, &block)
        AppOptics::API.log_entry('actionview')
        render_without_appoptics(options, extra_options, &block)

      rescue Exception => e
        AppOptics::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        AppOptics::API.log_exit('actionview')
      end
    end
  end
end
