# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module Utils
        def extract_trace_details(sql, name = nil)
          opts = {}

          opts[:Query] = sql.to_s
          opts[:Name] = name.to_s if name 

          if defined?(ActiveRecord::Base.connection.cfg)
            opts[:Database] = ActiveRecord::Base.connection.cfg[:database]
            if ActiveRecord::Base.connection.cfg.has_key?(:host)
              opts[:RemoteHost] = ActiveRecord::Base.connection.cfg[:host]
            end
          end

          if defined?(ActiveRecord::Base.connection.adapter_name)
            opts[:Flavor] = ActiveRecord::Base.connection.adapter_name
          end

          return opts || {}
        end

        # We don't want to trace framework caches.  Only instrument SQL that
        # directly hits the database.
        def ignore_payload?(name)
          %w(SCHEMA EXPLAIN CACHE).include? name.to_s or (name and name.to_sym == :skip_logging)
        end

        def cfg
          @config
        end
      end # Utils
      
      module PostgreSQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias exec_query_without_oboe exec_query
            alias exec_query exec_query_with_oboe
            
            alias exec_delete_without_oboe exec_delete
            alias exec_delete exec_delete_with_oboe
          end
        end
        
        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
        
        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end
      end # PostgreSQLAdapter

      module LegacyPostgreSQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias execute_without_oboe execute
            alias execute execute_with_oboe
          end
        end
        
        def execute_with_oboe(sql, name = nil)
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              execute_without_oboe(sql, name)
            end
          else
            execute_without_oboe(sql, name)
          end
        end
      end # LegacyPostgreSQLAdapter

      module AbstractMySQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias execute_without_oboe execute
            alias execute execute_with_oboe
          end
        end
        
        def execute_with_oboe(sql, name = nil)
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              execute_without_oboe(sql, name)
            end
          else
            execute_without_oboe(sql, name)
          end
        end
      end # AbstractMySQLAdapter

      module MySQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias exec_query_without_oboe exec_query
            alias exec_query exec_query_with_oboe
          end
        end
        
        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
      end # MySQLAdapter

      module LegacyMySQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias execute_without_oboe execute
            alias execute execute_with_oboe
            
            if Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR > 0
              alias exec_query_without_oboe exec_query
              alias exec_query exec_query_with_oboe
              
              alias exec_delete_without_oboe exec_delete
              alias exec_delete exec_delete_with_oboe
            end
          end
        end
        
        def execute_with_oboe(sql, name = nil)
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              execute_without_oboe(sql, name)
            end
          else
            execute_without_oboe(sql, name)
          end
        end
        
        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
        
        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end
      end # LegacyMySQLAdapter
      
      module MySQL2Adapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            alias exec_insert_without_oboe exec_insert
            alias exec_insert exec_insert_with_oboe
            
            alias exec_query_without_oboe exec_query
            alias exec_query exec_query_with_oboe
            
            alias exec_delete_without_oboe exec_delete
            alias exec_delete exec_delete_with_oboe
          end
        end
        
        def exec_insert_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_insert_without_oboe(sql, name, binds)
            end
          else
            exec_insert_without_oboe(sql, name, binds)
          end
        end
        
        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
        
        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe::Config.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('ActiveRecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end
      end # MySQL2Adapter

      module FlavorInitializers
        def self.mysql
          if ActiveRecord::Base::connection.adapter_name.downcase.to_sym == :mysql
            puts "[oboe_fu/loading] Instrumenting ActiveRecord MysqlAdapter" if Oboe::Config[:verbose]
            if Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR > 1
              ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.module_eval do
                include Oboe::Inst::ConnectionAdapters::AbstractMySQLAdapter
              end
              ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
                include Oboe::Inst::ConnectionAdapters::MySQLAdapter
              end
            else
              ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
                include Oboe::Inst::ConnectionAdapters::LegacyMySQLAdapter
              end
            end
          end
        end

        def self.mysql2
          if ActiveRecord::Base::connection.adapter_name.downcase.to_sym == :mysql2
            puts "[oboe_fu/loading] Instrumenting ActiveRecord Mysql2Adapter" if Oboe::Config[:verbose]
            ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
              include Oboe::Inst::ConnectionAdapters::MySQL2Adapter
            end
          end
        end

        def self.postgresql
          if ActiveRecord::Base::connection.adapter_name.downcase.to_sym == :postgresql
            puts "[oboe_fu/loading] Instrumenting ActiveRecord PostgreSQLAdapter" if Oboe::Config[:verbose]
            ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
              if Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR > 0
                include Oboe::Inst::ConnectionAdapters::PostgreSQLAdapter
              else
                include Oboe::Inst::ConnectionAdapters::LegacyPostgreSQLAdapter
              end
            end
          end
        end

        def self.oracle
          if ActiveRecord::Base::connection.adapter_name.downcase.to_sym == :oracleenhanced
            puts "[oboe_fu/loading] Instrumenting ActiveRecord OracleEnhancedAdapter" if Oboe::Config[:verbose]
            ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters
            end
          end
        end
      end
    end
  end
end

if Rails::VERSION::MAJOR == 3
  Rails.configuration.after_initialize do
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle
  end
else
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle
end
