# Copyright (c) 2016 AppNeta, Inc.
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

      def self.included(base)
        alias :perform_action_without_traceview :perform_action
        alias :rescue_action_without_traceview :rescue_action
        alias :process_without_traceview :process
        alias :render_without_traceview :render
      end

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
end
