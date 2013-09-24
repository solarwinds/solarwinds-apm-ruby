# Copyright (c) 2013 by AppNeta
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module Utils
        
        def extract_trace_details(sql, name = nil, binds = [])
          opts = {}

          begin
            if binds.empty? 
              # Raw SQL.  Sanitize if requested
              if Oboe::Config[:sanitize_sql]
                opts[:Query] = sql.gsub(/\'[\s\S][^\']*\'/, '?')
              else
                opts[:Query] = sql.to_s
              end
            else
              # We have bind parameters.  Only report if :sanitize_sql isn't true
              unless Oboe::Config[:sanitize_sql]
                opts[:Query] = sql.to_s
                opts[:QueryArgs] = binds.map { |col, val| type_cast(val, col) }
              else
                opts[:Query] = sql.gsub(/\'[\s\S][^\']*\'/, '?')
              end
            end

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
            Oboe.logger.debug "Exception raised capturing ActiveRecord KVs: #{e.inspect}"
            Oboe.logger.debug e.backtrace.join("\n")
          end

          return opts || {}
        end

        # We don't want to trace framework caches.  Only instrument SQL that
        # directly hits the database.
        def ignore_payload?(name)
          %w(SCHEMA EXPLAIN CACHE).include? name.to_s or 
            (name and name.to_sym == :skip_logging) or
              name == "ActiveRecord::SchemaMigration Load"
        end

        #def cfg
        #  @config
        #end
        
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

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end
        
        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end
        
        def exec_insert_with_oboe(sql, name = nil, binds = [], *args)
          if Oboe.tracing? and !ignore_payload?(name)

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_insert_without_oboe(sql, name, binds, *args)
            end
          else
            exec_insert_without_oboe(sql, name, binds, *args)
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
    end
  end
end

