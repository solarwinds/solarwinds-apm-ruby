# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
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
      rescue => e
        TraceView.logger.debug "[traceview/debug] Error searching Rails handlers: #{e.message}"
        return false
      end

      #
      # log_rails_error?
      #
      # Determins whether we should log a raised exception to the
      # TraceView dashboard.  This is determined by whether the exception
      # has a rescue handler setup and the value of
      # TraceView::Config[:report_rescued_errors]
      #
      def log_rails_error?(exception)
        # As it's perculating up through the layers...  make sure that
        # we only report it once.
        return false if exception.instance_variable_get(:@traceview_logged)

        has_handler = has_handler?(exception)

        if !has_handler || (has_handler && TraceView::Config[:report_rescued_errors])
          return true
        end
        false
      end

      #
      # render_with_traceview
      #
      # Our render wrapper that just times and conditionally
      # reports raised exceptions
      #
      def render_with_traceview(*args, &blk)
        TraceView::API.log_entry('actionview')
        render_without_traceview(*args, &blk)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('actionview')
      end
    end

    #
    # ActionController3
    #
    # This modules contains the instrumentation code specific
    # to Rails v3
    #
    module ActionController3
      include ::TraceView::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process, :traceview
          alias_method_chain :process_action, :traceview
          alias_method_chain :render, :traceview
        end
      end

      def process_with_traceview(*args)
        TraceView::API.log_entry('rails')
        process_without_traceview(*args)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('rails')
      end

      def process_action_with_traceview(*args)
        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        TraceView::API.log(nil, 'info', report_kvs)

        process_action_without_traceview(*args)
      rescue Exception
        report_kvs[:Status] = 500
        TraceView::API.log(nil, 'info', report_kvs)
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
      include ::TraceView::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process_action, :traceview
          alias_method_chain :render, :traceview
        end
      end

      def process_action_with_traceview(method_name, *args)
        report_kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }

        TraceView::API.log_entry('rails', report_kvs)
        process_action_without_traceview(method_name, *args)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('rails')
      end
    end
  end
end

if defined?(ActionController::Base) && TraceView::Config[:action_controller][:enabled]
  if ::Rails::VERSION::MAJOR == 4

    class ActionController::Base
      include TraceView::Inst::ActionController4
    end

  elsif ::Rails::VERSION::MAJOR == 3

    class ActionController::Base
      include TraceView::Inst::ActionController3
    end

  elsif ::Rails::VERSION::MAJOR == 2

    ActionController::Base.class_eval do
      include ::TraceView::Inst::RailsBase

      alias :perform_action_without_traceview :perform_action
      alias :rescue_action_without_traceview :rescue_action
      alias :process_without_traceview :process
      alias :render_without_traceview :render

      def process(*args)
        TraceView::API.log_entry('rails')
        process_without_traceview(*args)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('rails')
      end

      def perform_action(*arguments)
        report_kvs = {
          :Controller  => @_request.path_parameters['controller'],
          :Action      => @_request.path_parameters['action']
        }
        TraceView::API.log(nil, 'info', report_kvs)
        perform_action_without_traceview(*arguments)
      end

      def rescue_action(exn)
        TraceView::API.log_exception(nil, exn) if log_rails_error?(exn)
        rescue_action_without_traceview(exn)
      end

      def render(options = nil, extra_options = {}, &block)
        TraceView::API.log_entry('actionview')
        render_without_traceview(options, extra_options, &block)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('actionview')
      end
    end
  end
  TraceView.logger.info '[traceview/loading] Instrumenting actioncontroler' if TraceView::Config[:verbose]
end
# vim:set expandtab:tabstop=2
