# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v5
    #
    module ActionController
      include ::TraceView::Inst::RailsBase

      def process_action(method_name, *args)
        return super(method_name, *args) unless tracing?
        begin
          kvs = {
              :Controller   => self.class.name,
              :Action       => self.action_name,
          }
          kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:action_controller][:collect_backtraces]

          TraceView::API.log_entry('rails', kvs)
          super(method_name, *args)

        rescue Exception => e
          TraceView::API.log_exception(nil, e) if log_rails_error?(e)
          raise
        ensure
          TraceView::API.log_exit('rails')
        end
      end

      #
      # render
      #
      # Our render wrapper that calls 'add_logging', which will log if we are tracing
      #
      def render(*args, &blk)
        add_logging('actionview') do
          super(*args, &blk)
        end
      end
    end
  end
end
