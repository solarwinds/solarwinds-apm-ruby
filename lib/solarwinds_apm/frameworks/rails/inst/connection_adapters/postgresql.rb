# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting activerecord postgresqladapter' if SolarWindsAPM::Config[:verbose]

          SolarWindsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  SolarWindsAPM::Inst::ConnectionAdapters::Utils)

          SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
          SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_update)
          SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)
        end
      end
    end
  end
end
