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
        kvs = {
            :Controller   => self.class.name,
            :Action       => self.action_name,
        }
        request.env['traceview.transaction'] = "#{kvs[:Controller]}.#{kvs[:Action]}"

        return super(method_name, *args) unless TraceView.tracing?
        begin
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
      # Our render wrapper that calls 'trace', which will log if we are tracing
      #
      def render(*args, &blk)
        trace('actionview') do
          super(*args, &blk)
        end
      end
    end
  end
end
