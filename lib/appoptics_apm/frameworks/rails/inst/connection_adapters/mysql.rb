# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql
          AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting activerecord mysqladapter' if AppOpticsAPM::Config[:verbose]

          # ActiveRecord 3.2 and higher
          if (ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 2) ||
              ActiveRecord::VERSION::MAJOR == 4

            # AbstractMysqlAdapter
            AppOpticsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter,
                                    AppOpticsAPM::Inst::ConnectionAdapters::Utils)
            AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter, :execute)

            # MysqlAdapter
            AppOpticsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    AppOpticsAPM::Inst::ConnectionAdapters::Utils)
            AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_query)

          else
            # ActiveRecord 3.1 and below

            # MysqlAdapter
            AppOpticsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::MysqlAdapter,
                                    AppOpticsAPM::Inst::ConnectionAdapters::Utils)

            AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::MysqlAdapter, :execute)

            if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 1
              AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::MysqlAdapter, :begin_db_transaction)
              AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::MysqlAdapter, :exec_delete)
            end
          end
        end
      end
    end
  end
end
