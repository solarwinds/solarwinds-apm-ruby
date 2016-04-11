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
        rescue_handlers.detect do |klass_name, _handler|
          # Rescue handlers can be specified as strings or constant names
          klass = self.class.const_get(klass_name) rescue nil
          klass ||= klass_name.constantize rescue nil
          has_handler = exception.is_a?(klass) if klass
        end
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
  end
end

if defined?(ActionController::Base) && TraceView::Config[:action_controller][:enabled]
  TraceView.logger.info '[traceview/loading] Instrumenting actioncontroller' if TraceView::Config[:verbose]
  require "traceview/frameworks/rails/inst/action_controller#{Rails::VERSION::MAJOR}"
  ::TraceView::Util.send_include(::ActionController::Base, TraceView::Inst::ActionController)

  # ActionController::API
  if Rails::VERSION::MAJOR == 5
    TraceView.logger.info '[traceview/loading] Instrumenting actioncontroller api' if TraceView::Config[:verbose]
    require "traceview/frameworks/rails/inst/action_controller#{Rails::VERSION::MAJOR}_api"
    ::TraceView::Util.send_include(::ActionController::API, TraceView::Inst::ActionControllerAPI)
  end
end
# vim:set expandtab:tabstop=2
