# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql
          TraceView.logger.info '[traceview/loading] Instrumenting activerecord mysqladapter' if TraceView::Config[:verbose]

          # ActiveRecord 3.2 and higher
          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR >= 2) ||
              ::ActiveRecord::VERSION::MAJOR == 4

            # AbstractMysqlAdapter
            TraceView::Util.send_include(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter,
                                    ::TraceView::Inst::ConnectionAdapters::Utils)
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter, :execute)

            # MysqlAdapter
            TraceView::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::TraceView::Inst::ConnectionAdapters::Utils)
            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_query)

          else
            # ActiveRecord 3.1 and below

            # MysqlAdapter
            TraceView::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::TraceView::Inst::ConnectionAdapters::Utils)

            TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :execute)

            if ::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 1
              TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :begin_db_transaction)
              TraceView::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_delete)
            end
          end
        end
      end
    end
  end
end
