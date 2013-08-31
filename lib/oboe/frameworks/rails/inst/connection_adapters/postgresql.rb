# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.postgresql

          Oboe.logger.info "[oboe/loading] Instrumenting activerecord postgresqladapter" if Oboe::Config[:verbose]

          ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
            include Oboe::Inst::ConnectionAdapters::Utils

            if (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0) or ::Rails::VERSION::MAJOR == 4

              # ActiveRecord 3.1 and up
              if method_defined?(:exec_query)
                alias_method :exec_query_without_oboe, :exec_query
                alias_method :exec_query, :exec_query_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument PostgreSQLAdapter:exec_query"
              end
                
              if method_defined?(:exec_delete)
                alias_method :exec_delete_without_oboe, :exec_delete
                alias_method :exec_delete, :exec_delete_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument PostgreSQLAdapter:exec_delete"
              end

            else

              # ActiveRecord 3.0 and prior
              if method_defined?(:execute)
                alias_method :execute_without_oboe, :execute
                alias_method :execute, :execute_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument PostgreSQLAdapter:execute"
              end

            end
          end if defined?(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        end
      end
    end
  end
end
