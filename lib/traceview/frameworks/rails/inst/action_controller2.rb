# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v2
    #
    module ActionController
      include ::TraceView::Inst::RailsBase

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :perform_action)
        ::TraceView::Util.method_alias(klass, :rescue_action)
        ::TraceView::Util.method_alias(klass, :process)
        ::TraceView::Util.method_alias(klass, :render)
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

      def perform_action_with_traceview(*arguments)
        kvs = {
          :Controller  => @_request.path_parameters['controller'],
          :Action      => @_request.path_parameters['action']
        }
        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:action_controller][:collect_backtraces]

        TraceView::API.log(nil, 'info', kvs)
        perform_action_without_traceview(*arguments)
      end

      def rescue_action_with_traceview(exn)
        TraceView::API.log_exception(nil, exn) if log_rails_error?(exn)
        rescue_action_without_traceview(exn)
      end

      def render_with_traceview(options = nil, extra_options = {}, &block)
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
end
