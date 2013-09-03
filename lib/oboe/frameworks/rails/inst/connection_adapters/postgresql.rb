# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters

      module PostgreSQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::method_defined? :exec_query
              alias exec_query_without_oboe exec_query
              alias exec_query exec_query_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
              
            if ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::method_defined? :exec_delete
              alias exec_delete_without_oboe exec_delete
              alias exec_delete exec_delete_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
          end
        end
      end # PostgreSQLAdapter

      module LegacyPostgreSQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::method_defined? :execute
              alias execute_without_oboe execute
              alias execute execute_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
          end
        end
      end # LegacyPostgreSQLAdapter

      module FlavorInitializers
        def self.postgresql
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord postgresqladapter" if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
            if (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0) or ::Rails::VERSION::MAJOR == 4
              include Oboe::Inst::ConnectionAdapters::PostgreSQLAdapter
            else
              include Oboe::Inst::ConnectionAdapters::LegacyPostgreSQLAdapter
            end
          end if defined?(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        end
      end

    end
  end
end
