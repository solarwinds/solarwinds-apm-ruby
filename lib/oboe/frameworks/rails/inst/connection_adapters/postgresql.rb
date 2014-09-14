# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          Oboe.logger.info '[oboe/loading] Instrumenting activerecord postgresqladapter' if Oboe::Config[:verbose]

          Oboe::Util.send_include(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter,
                                  ::Oboe::Inst::ConnectionAdapters::Utils)

          if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR > 0) ||
                ::ActiveRecord::VERSION::MAJOR == 4

            # ActiveRecord 3.1 and up
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_query)
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :exec_delete)

          else
            # ActiveRecord 3.0 and prior
            Oboe::Util.method_alias(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, :execute)
          end
        end
      end
    end
  end
end
