# Copyright (c) 2016 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    #
    # ActionController
    #
    # This modules contains the instrumentation code specific
    # to Rails v5.
    #
    module ActionControllerAPI
      include ::TraceView::Inst::RailsBase

      def process_action(method_name, *args)
        kvs = {
          :Controller   => self.class.name,
          :Action       => self.action_name,
        }
        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:action_controller_api][:collect_backtraces]

        TraceView::API.log_entry('rails-api', kvs)
        super(method_name, *args)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('rails-api')
      end

      #
      # render
      #
      # Our render wrapper that just times and conditionally
      # reports raised exceptions
      #
      def render(*args, &blk)
        TraceView::API.log_entry('actionview')
        super(*args, &blk)

      rescue Exception => e
        TraceView::API.log_exception(nil, e) if log_rails_error?(e)
        raise
      ensure
        TraceView::API.log_exit('actionview')
      end
    end
  end
end
