# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          AppOptics.logger.info '[appoptics/loading] Instrumenting activerecord postgresqladapter' if AppOptics::Config[:verbose]

          AppOptics::Util.send_include(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  ::AppOptics::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR > 0) ||
                ::ActiveRecord::VERSION::MAJOR >= 4

            # ActiveRecord 3.1 and up
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)

          else
            # ActiveRecord 3.0 and prior
            AppOptics::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :execute)
          end
        end
      end
    end
  end
end
