# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters

      module AbstractMysqlAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::method_defined? :execute
              alias execute_without_oboe execute
              alias execute execute_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
          end
        end
      end # AbstractMysqlAdapter

      module MysqlAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :exec_query
              alias exec_query_without_oboe exec_query
              alias exec_query exec_query_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
          end
        end
      end # MysqlAdapter

      module LegacyMysqlAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :execute
              alias execute_without_oboe execute
              alias execute execute_with_oboe
            else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
            
            if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 1
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :begin_db_transaction
                alias begin_db_transaction_without_oboe begin_db_transaction
                alias begin_db_transaction begin_db_transaction_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
            
            if (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0) or ::Rails::VERSION::MAJOR == 4
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :exec_query
                alias exec_query_without_oboe exec_query
                alias exec_query exec_query_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
              
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :exec_delete
                alias exec_delete_without_oboe exec_delete
                alias exec_delete exec_delete_with_oboe
              else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
          end
        end
      end # LegacyMysqlAdapter

      module FlavorInitializers
        def self.mysql
          Oboe.logger.info "[oboe/loading] Instrumenting activerecord mysqladapter" if Oboe::Config[:verbose]
          if (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 1) or ::Rails::VERSION::MAJOR == 4
            ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::AbstractMysqlAdapter
            end if defined?(::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter) 

            ::ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::MysqlAdapter
            end if defined?(::ActiveRecord::ConnectionAdapters::MysqlAdapter)
          else
            ::ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::LegacyMysqlAdapter
            end if defined?(::ActiveRecord::ConnectionAdapters::MysqlAdapter)
          end
        end
      end
    end
  end
end
