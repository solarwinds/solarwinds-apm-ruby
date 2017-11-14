# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql
          AppOptics.logger.info '[appoptics/loading] Instrumenting activerecord mysqladapter' if AppOptics::Config[:verbose]

          # ActiveRecord 3.2 and higher
          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR >= 2) ||
              ::ActiveRecord::VERSION::MAJOR == 4

            # AbstractMysqlAdapter
            AppOptics::Util.send_include(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter,
                                    ::AppOptics::Inst::ConnectionAdapters::Utils)
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter, :execute)

            # MysqlAdapter
            AppOptics::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::AppOptics::Inst::ConnectionAdapters::Utils)
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_query)

          else
            # ActiveRecord 3.1 and below

            # MysqlAdapter
            AppOptics::Util.send_include(::ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    ::AppOptics::Inst::ConnectionAdapters::Utils)

            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :execute)

            if ::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 1
              AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :begin_db_transaction)
              AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_delete)
            end
          end
        end
      end
    end
  end
end
