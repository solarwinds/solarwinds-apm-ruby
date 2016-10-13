# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          TraceView.logger.info '[traceview/loading] Instrumenting activerecord postgresqladapter' if TraceView::Config[:verbose]

          TraceView::Util.send_include(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  ::TraceView::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR > 0) ||
                ::ActiveRecord::VERSION::MAJOR >= 4

            # ActiveRecord 3.1 and up
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)

          else
            # ActiveRecord 3.0 and prior
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :execute)
          end
        end
      end
    end
  end
end
