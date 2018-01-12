# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting activerecord mysql2adapter' if AppOpticsAPM::Config[:verbose]

          AppOpticsAPM::Util.send_include(::ActiveRecord::ConnectionAdapters::Mysql2Adapter,
                                  ::AppOpticsAPM::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 0) ||
              ::ActiveRecord::VERSION::MAJOR == 2
            # ActiveRecord 3.0 and prior
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :execute)
          else
            # ActiveRecord 3.1 and above
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_insert)
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_query)
            AppOpticsAPM::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_delete)
          end
        end
      end
    end
  end
end
