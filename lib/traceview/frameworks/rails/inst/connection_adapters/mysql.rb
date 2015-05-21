# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql
          Oboe.logger.info '[oboe/loading] Instrumenting activerecord mysqladapter' if Oboe::Config[:verbose]

          # ActiveRecord 3.2 and higher
          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR >= 2) ||
              ::ActiveRecord::VERSION::MAJOR == 4

            # AbstractMysqlAdapter
            Oboe::Util.send_include(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter,
                                    ::Oboe::Inst::ConnectionAdapters::Utils)
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter, :execute)

            # MysqlAdapter
            Oboe::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::Oboe::Inst::ConnectionAdapters::Utils)
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_query)

          else
            # ActiveRecord 3.1 and below

            # MysqlAdapter
            Oboe::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::Oboe::Inst::ConnectionAdapters::Utils)

            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :execute)

            if ::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 1
              Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :begin_db_transaction)
              Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_delete)
            end
          end
        end
      end
    end
  end
end
