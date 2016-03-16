# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v4
    #
    module ActionController
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

