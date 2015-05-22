# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          TraceView.logger.info '[traceview/loading] Instrumenting activerecord mysql2adapter' if TraceView::Config[:verbose]

          TraceView::Util.send_include(::ActiveRecord::ConnectionAdapters::Mysql2Adapter,
                                  ::TraceView::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 0) ||
              ::ActiveRecord::VERSION::MAJOR == 2
            # ActiveRecord 3.0 and prior
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :execute)
          else
            # ActiveRecord 3.1 and above
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_insert)
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_query)
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_delete)
          end
        end
      end
    end
  end
end
