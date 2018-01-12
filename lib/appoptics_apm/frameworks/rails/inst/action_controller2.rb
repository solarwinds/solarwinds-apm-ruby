# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v2
    #
    module ActionController
      include ::AppOpticsAPM::Inst::RailsBase

      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :perform_action)
        ::AppOpticsAPM::Util.method_alias(klass, :rescue_action)
        ::AppOpticsAPM::Util.method_alias(klass, :process)
        ::AppOpticsAPM::Util.method_alias(klass, :render)
      end

      def process_with_appoptics(*args)
        AppOpticsAPM::API.log_entry('rails')
        process_without_appoptics(*args)

      rescue Exception => e
        AppOpticsAPM::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        AppOpticsAPM::API.log_exit('rails')
      end

      def perform_action_with_appoptics(*arguments)
        kvs = {
          :Controller  => @_request.path_parameters['controller'],
          :Action      => @_request.path_parameters['action']
        }
        kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:action_controller][:collect_backtraces]

        AppOpticsAPM::API.log(nil, 'info', kvs)
        perform_action_without_appoptics(*arguments)
      end

      def rescue_action_with_appoptics(exn)
        AppOpticsAPM::API.log_exception(nil, exn) if log_rails_error?(exn)
        rescue_action_without_appoptics(exn)
      end

      def render_with_appoptics(options = nil, extra_options = {}, &block)
        AppOpticsAPM::API.log_entry('actionview')
        render_without_appoptics(options, extra_options, &block)

      rescue Exception => e
        AppOpticsAPM::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        AppOpticsAPM::API.log_exit('actionview')
      end
    end
  end
end
