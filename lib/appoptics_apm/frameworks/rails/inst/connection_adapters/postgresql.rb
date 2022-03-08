# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting activerecord postgresqladapter' if AppOpticsAPM::Config[:verbose]

          AppOpticsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  AppOpticsAPM::Inst::ConnectionAdapters::Utils)

          AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
          AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_update)
          AppOpticsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)
        end
      end
    end
  end
end
