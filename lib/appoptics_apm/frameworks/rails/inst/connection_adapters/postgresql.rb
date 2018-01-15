# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting activerecord postgresqladapter' if AppOpticsAPM::Config[:verbose]

          AppOpticsAPM::Util.send_include(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  ::AppOpticsAPM::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR > 0) ||
                ::ActiveRecord::VERSION::MAJOR >= 4

            # ActiveRecord 3.1 and up
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)

          else
            # ActiveRecord 3.0 and prior
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :execute)
          end
        end
      end
    end
  end
end
