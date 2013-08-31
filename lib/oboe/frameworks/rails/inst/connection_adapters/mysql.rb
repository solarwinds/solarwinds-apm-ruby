# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord mysqladapter" if Oboe::Config[:verbose]

          # ActiveRecord 3.2 and higher
          if (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR >= 2) or ::Rails::VERSION::MAJOR == 4

            ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::Utils

              if method_defined?(:execute)
                alias_method :execute_without_oboe, :execute
                alias_method :execute, :execute_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument AbstractMysqlAdapter.execute"
              end
            end

            ::ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::Utils
              
              if method_defined?(:execute)
                alias_method :exec_query_without_oboe, :exec_query
                alias_method :exec_query, :exec_query_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument MysqlAdapter.exec_query"
              end
            end

          else
            # ActiveRecord 3.1 and below
            ::ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::Utils
              
              if method_defined?(:execute)
                alias_method :execute_without_oboe, :execute
                alias_method :execute, :execute_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument MysqlAdapter.execute"
              end
                
              if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 1

                if method_defined?(:begin_db_transaction)
                  alias_method :begin_db_transaction_without_oboe, :begin_db_transaction
                  alias_method :begin_db_transaction, :begin_db_transaction_with_oboe
                else
                  Oboe.logger.debug "[oboe/loading] Couldn't instrument MysqlAdapter.begin_db_transaction"
                end
              end
              
              if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0 

                if method_defined?(:exec_query)
                  alias_method :exec_query_without_oboe, :exec_query
                  alias_method :exec_query, :exec_query_with_oboe
                else
                  Oboe.logger.debug "[oboe/loading] Couldn't instrument MysqlAdapter.exec_query"
                end

                if method_defined?(:exec_delete)
                  alias_method :exec_delete_without_oboe, :exec_delete
                  alias_method :exec_delete, :exec_delete_with_oboe
                else
                  Oboe.logger.debug "[oboe/loading] Couldn't instrument MysqlAdapter.exec_delete"
                end
              end

            end
          end
        end
      end
    end
  end
end
