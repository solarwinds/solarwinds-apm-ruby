# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v3
    #
    module ActionController
      include ::TraceView::Inst::RailsBase

      def self.included(base)
        base.class_eval do
          alias_method_chain :process, :traceview
          alias_method_chain :process_action, :traceview
          alias_method_chain :render, :traceview
        end
      end

      def process_with_traceview(*args)
        add_logging('rails') do
          process_without_traceview(*args)
        end
      end

      def process_action_with_traceview(*args)
        return process_action_without_traceview(*args) unless tracing?
        begin
          kvs = {
              :Controller   => self.class.name,
              :Action       => action_name,
          }
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:action_controller][:collect_backtraces]
          TraceView::API.log(nil, 'info', kvs)

          process_action_without_traceview(*args)
        rescue Exception
          kvs[:Status] = 500
          TraceView::API.log(nil, 'info', kvs)
          raise
        end
      end
    end
  end
end
