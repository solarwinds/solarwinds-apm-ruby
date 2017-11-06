# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          AppOptics.logger.info '[appoptics/loading] Instrumenting activerecord mysql2adapter' if AppOptics::Config[:verbose]

          AppOptics::Util.send_include(::ActiveRecord::ConnectionAdapters::Mysql2Adapter,
                                  ::AppOptics::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 0) ||
              ::ActiveRecord::VERSION::MAJOR == 2
            # ActiveRecord 3.0 and prior
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :execute)
          else
            # ActiveRecord 3.1 and above
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_insert)
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_query)
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::Mysql2Adapter, :exec_delete)
          end
        end
      end
    end
  end
end
