# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module FlavorInitializers
        def self.mysql2
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord mysql2adapter" if Oboe::Config[:verbose]

          ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
            include Oboe::Inst::ConnectionAdapters::Utils
            
            if ::Rails::VERSION::MAJOR == 2 or (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 0)

              if method_defined?(:execute)
                alias_method :execute_without_oboe, :execute
                alias_method :execute, :execute_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument Mysql2Adapter.execute"
              end
            else
              
              if method_defined?(:exec_insert)
                alias_method :exec_insert_without_oboe, :exec_insert
                alias_method :exec_insert, :exec_insert_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument Mysql2Adapter.exec_insert"
              end
           
              # In Rails 3.1, :exec_query was defined as a private method
              if method_defined?(:exec_query) or private_method_defined?(:exec_query)
                alias_method :exec_query_without_oboe, :exec_query
                alias_method :exec_query, :exec_query_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument Mysql2Adapter.exec_query"
              end
            
              if method_defined?(:exec_delete)
                alias_method :exec_delete_without_oboe, :exec_delete
                alias_method :exec_delete, :exec_delete_with_oboe
              else
                Oboe.logger.debug "[oboe/loading] Couldn't instrument Mysql2Adapter.exec_delete"
              end
            end
          end if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        end
      end

    end
  end
end
