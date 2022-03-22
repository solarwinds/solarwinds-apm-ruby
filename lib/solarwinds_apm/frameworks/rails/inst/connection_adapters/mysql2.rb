# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting activerecord mysql2adapter' if SolarWindsAPM::Config[:verbose]

          SolarWindsAPM::Util.send_include(ActiveRecord::ConnectionAdapters::Mysql2Adapter,
                                  SolarWindsAPM::Inst::ConnectionAdapters::Utils)

          if (ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0) ||
              ActiveRecord::VERSION::MAJOR == 2
            # ActiveRecord 3.0 and prior
            SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::Mysql2Adapter, :execute)
          else
            # ActiveRecord 3.1 and above
            SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_insert)
            SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_query)
            SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_update)
            SolarWindsAPM::Util.method_alias(ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_delete)
          end
        end
      end
    end
  end
end
