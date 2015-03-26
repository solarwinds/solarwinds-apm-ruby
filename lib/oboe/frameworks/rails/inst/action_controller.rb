# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    #
    # RailsBase
    #
    # This module contains the instrumentation code common to
    # many Rails versions.
    #
    module RailsBase
      #
      # has_handler?
      #
      # Determins if <tt>exception</tt> has a registered
      # handler via <tt>rescue_from</tt>
      #
      def has_handler?(exception)
        # Don't log exceptions if they have a rescue handler set
        has_handler = false
        rescue_handlers.detect { | klass_name, handler |
          # Rescue handlers can be specified as strings or constant names
          klass = self.class.const_get(klass_name) rescue nil
          klass ||= klass_name.constantize rescue nil
          has_handler = exception.is_a?(klass) if klass
        }
        has_handler
      end

      #
      # log_rails_error?
      #
      # Determins whether we should log a raised exception to the
      # TraceView dashboard.  This is determined by whether the exception
      # has a rescue handler setup and the value of
      # Oboe::Config[:report_rescued_errors]
      #
      def log_rails_error?(exception)
        has_handler = has_handler?(exception)

        if !has_handler || (has_handler && Oboe::Config[:report_rescued_errors])
          return true
        end
        false
      end

      #
      # render_with_oboe
      #
      # Our render wrapper that just times and conditionally
      # reports raised exceptions
      #
      def render_with_oboe(*args)
        Oboe::API.log_entry('actionview')
        render_without_oboe(*args)

      rescue Exception => e
        Oboe::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        Oboe::API.log_exit('actionview')
      end
    end

    #
    # ActionController3
    #
    # This modules contains the instrumentation code specific
    # to Rails v3
    #
    module ActionController3
      include ::Oboe::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process, :oboe
          alias_method_chain :process_action, :oboe
          alias_method_chain :render, :oboe
        end
      end

      def process_with_oboe(*args)
        Oboe::API.log_entry('rails')
        process_without_oboe *args

      rescue Exception => e
        Oboe::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        Oboe::API.log_exit('rails')
      end

      def process_action_with_oboe(*args)
        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        Oboe::API.log(nil, 'info', report_kvs)

        process_action_without_oboe *args
      rescue Exception => exception
        report_kvs[:Status] = 500
        Oboe::API.log(nil, 'info', report_kvs)
        raise
      end
    end

    #
    # ActionController4
    #
    # This modules contains the instrumentation code specific
    # to Rails v4
    #
    module ActionController4
      include ::Oboe::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process_action, :oboe
          alias_method_chain :render, :oboe
        end
      end

      def process_action_with_oboe(method_name, *args)
        return process_action_without_oboe(method_name, *args) if Oboe::Config[:action_blacklist].present? &&
          Oboe::Config[:action_blacklist][[self.controller_name, self.action_name].join('#')]

        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }

        Oboe::API.log_entry('rails')
        process_action_without_oboe(method_name, *args)

      rescue Exception => e
        Oboe::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        Oboe::API.log_exit('rails')
      end
    end
  end
end

if defined?(ActionController::Base) && Oboe::Config[:action_controller][:enabled]
  if ::Rails::VERSION::MAJOR == 4

    class ActionController::Base
      include Oboe::Inst::ActionController4
    end

  elsif ::Rails::VERSION::MAJOR == 3

    class ActionController::Base
      include Oboe::Inst::ActionController3
    end

  elsif ::Rails::VERSION::MAJOR == 2

    ActionController::Base.class_eval do
      alias :perform_action_without_oboe :perform_action
      alias :rescue_action_without_oboe :rescue_action
      alias :process_without_oboe :process
      alias :render_without_oboe :render

      def process(*args)
        Oboe::API.trace('rails', {}) do
          process_without_oboe(*args)
        end
      end

      def perform_action(*arguments)
        report_kvs = {
          :Controller  => @_request.path_parameters['controller'],
          :Action      => @_request.path_parameters['action']
        }
        Oboe::API.log(nil, 'info', report_kvs)
        perform_action_without_oboe(*arguments)
      end

      def rescue_action(exn)
        Oboe::API.log_exception(nil, exn)
        rescue_action_without_oboe(exn)
      end

      def render(options = nil, extra_options = {}, &block)
        Oboe::API.trace('actionview', {}) do
          render_without_oboe(options, extra_options, &block)
        end
      end
    end
  end
  Oboe.logger.info '[oboe/loading] Instrumenting actioncontroler' if Oboe::Config[:verbose]
end
# vim:set expandtab:tabstop=2
