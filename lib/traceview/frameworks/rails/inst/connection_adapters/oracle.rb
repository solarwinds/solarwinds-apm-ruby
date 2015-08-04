# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.oracle
          TraceView.logger.info '[traceview/loading] Instrumenting activerecord oracleenhancedadapter' if TraceView::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.module_eval do
            include TraceView::Inst::ConnectionAdapters
          end if defined?(::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
        end
      end
    end
  end
end

