# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module Utils
        def extract_trace_details(sql, name = nil)
          opts = {}

          begin
            opts[:Query] = sql.to_s
            opts[:Name] = name.to_s if name
            opts[:Backtrace] = Oboe::API.backtrace

            if ::Rails::VERSION::MAJOR == 2
              config = ::Rails.configuration.database_configuration[::Rails.env]
            else
              config = ::Rails.application.config.database_configuration[::Rails.env]
            end  

            opts[:Database]   = config["database"] if config.has_key?("database")
            opts[:RemoteHost] = config["host"]     if config.has_key?("host")
            opts[:Flavor]     = config["adapter"]  if config.has_key?("adapter")
          rescue Exception => e
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
        
        def execute_with_oboe(sql, name = nil)
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('activerecord', opts || {}) do
              execute_without_oboe(sql, name)
            end
          else
            execute_without_oboe(sql, name)
          end
        end
        
        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
        
        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end
        
        def exec_insert_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_insert_without_oboe(sql, name, binds)
            end
          else
            exec_insert_without_oboe(sql, name, binds)
          end
        end
        
        def begin_db_transaction_with_oboe()
          if Oboe.tracing?
            opts = {}

            opts[:Query] = "BEGIN"
            Oboe::API.trace('activerecord', opts || {}) do
              begin_db_transaction_without_oboe()
            end
          else
            begin_db_transaction_without_oboe()
          end
        end
      end # Utils
      
      module PostgreSQLAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::method_defined? :exec_query
              alias exec_query_without_oboe exec_query
              alias exec_query exec_query_with_oboe
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
              
            if ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::method_defined? :exec_delete
              alias exec_delete_without_oboe exec_delete
              alias exec_delete exec_delete_with_oboe
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
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
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
          end
        end
      end # LegacyPostgreSQLAdapter

      module AbstractMysqlAdapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::method_defined? :execute
              alias execute_without_oboe execute
              alias execute execute_with_oboe
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
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
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
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
            else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
            end
            
            if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 1
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :begin_db_transaction
                alias begin_db_transaction_without_oboe begin_db_transaction
                alias begin_db_transaction begin_db_transaction_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
            
            if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :exec_query
                alias exec_query_without_oboe exec_query
                alias exec_query exec_query_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
              
              if ActiveRecord::ConnectionAdapters::MysqlAdapter::method_defined? :exec_delete
                alias exec_delete_without_oboe exec_delete
                alias exec_delete exec_delete_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
          end
        end
      end # LegacyMysqlAdapter
      
      module Mysql2Adapter
        include Oboe::Inst::ConnectionAdapters::Utils
      
        def self.included(cls)
          cls.class_eval do
            if ::Rails::VERSION::MAJOR == 2 or (::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR == 0)
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :execute
                alias execute_without_oboe execute
                alias execute execute_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            else
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_insert
                alias exec_insert_without_oboe exec_insert
                alias exec_insert exec_insert_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
             
              # In Rails 3.1, exec_query was defined as a private method
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_query or
                ActiveRecord::ConnectionAdapters::Mysql2Adapter::private_method_defined? :exec_query
                alias exec_query_without_oboe exec_query
                alias exec_query exec_query_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
              
              if ActiveRecord::ConnectionAdapters::Mysql2Adapter::method_defined? :exec_delete
                alias exec_delete_without_oboe exec_delete
                alias exec_delete exec_delete_with_oboe
              else puts "[oboe/loading] Couldn't properly instrument activerecord layer.  Partial traces may occur."
              end
            end
          end
        end
      end # Mysql2Adapter

      module FlavorInitializers
        def self.mysql
          puts "[oboe/loading] Instrumenting activerecord mysqladapter" if Oboe::Config[:verbose]
          if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 1
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

        def self.mysql2
          puts "[oboe/loading] Instrumenting activerecord mysql2adapter" if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
            include Oboe::Inst::ConnectionAdapters::Mysql2Adapter
          end if defined?(::ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        end

        def self.postgresql
          puts "[oboe/loading] Instrumenting activerecord postgresqladapter" if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
            if ::Rails::VERSION::MAJOR == 3 and ::Rails::VERSION::MINOR > 0
              include Oboe::Inst::ConnectionAdapters::PostgreSQLAdapter
            else
              include Oboe::Inst::ConnectionAdapters::LegacyPostgreSQLAdapter
            end
          end if defined?(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        end

        def self.oracle
          puts "[oboe/loading] Instrumenting activerecord oracleenhancedadapter" if Oboe::Config[:verbose]
          ::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.module_eval do
            include Oboe::Inst::ConnectionAdapters
          end if defined?(::ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
        end
      end
    end
  end
end

if Oboe::Config[:active_record][:enabled]
  begin
    adapter = ActiveRecord::Base::connection.adapter_name.downcase

    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql      if adapter == "mysql"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2     if adapter == "mysql2"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql if adapter == "postgresql"
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle     if adapter == "oracleenhanced"

  rescue Exception => e
    puts "[oboe/error] Oboe/ActiveRecord error: #{e.message}" if Oboe::Config[:verbose]
  end
end
# vim:set expandtab:tabstop=2
