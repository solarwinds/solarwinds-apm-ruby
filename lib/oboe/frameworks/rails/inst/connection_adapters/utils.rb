# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      module Utils

        def extract_trace_details(sql, name = nil, binds = [])
          opts = {}

          begin
            if Oboe::Config[:sanitize_sql]
              # Sanitize SQL and don't report binds
              opts[:Query] = sql.gsub(/\'[\s\S][^\']*\'/, '?')
            else
              # Report raw SQL and any binds if they exist
              opts[:Query] = sql.to_s
              opts[:QueryArgs] = binds.map { |col, val| type_cast(val, col) } unless binds.empty?
            end

            opts[:Name] = name.to_s if name
            opts[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:active_record][:collect_backtraces]

            if ::Rails::VERSION::MAJOR == 2
              config = ::Rails.configuration.database_configuration[::Rails.env]
            else
              config = ::Rails.application.config.database_configuration[::Rails.env]
            end

            opts[:Database]   = config['database'] if config.key?('database')
            opts[:RemoteHost] = config['host']     if config.key?('host')
            opts[:Flavor]     = config['adapter']  if config.key?('adapter')
          rescue StandardError => e
            Oboe.logger.debug "Exception raised capturing ActiveRecord KVs: #{e.inspect}"
            Oboe.logger.debug e.backtrace.join('\n')
          end

          return opts || {}
        end

        # We don't want to trace framework caches.  Only instrument SQL that
        # directly hits the database.
        def ignore_payload?(name)
          %w(SCHEMA EXPLAIN CACHE).include?(name.to_s) ||
            (name && name.to_sym == :skip_logging) ||
              name == 'ActiveRecord::SchemaMigration Load'
        end

        # def cfg
        #   @config
        # end

        def execute_with_oboe(sql, name = nil)
          if Oboe.tracing? && !ignore_payload?(name)

            opts = extract_trace_details(sql, name)
            Oboe::API.trace('activerecord', opts || {}) do
              execute_without_oboe(sql, name)
            end
          else
            execute_without_oboe(sql, name)
          end
        end

        def exec_query_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? && !ignore_payload?(name)

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_query_without_oboe(sql, name, binds)
            end
          else
            exec_query_without_oboe(sql, name, binds)
          end
        end

        def exec_delete_with_oboe(sql, name = nil, binds = [])
          if Oboe.tracing? && !ignore_payload?(name)

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_delete_without_oboe(sql, name, binds)
            end
          else
            exec_delete_without_oboe(sql, name, binds)
          end
        end

        def exec_insert_with_oboe(sql, name = nil, binds = [], *args)
          if Oboe.tracing? && !ignore_payload?(name)

            opts = extract_trace_details(sql, name, binds)
            Oboe::API.trace('activerecord', opts || {}) do
              exec_insert_without_oboe(sql, name, binds, *args)
            end
          else
            exec_insert_without_oboe(sql, name, binds, *args)
          end
        end

        def begin_db_transaction_with_oboe
          if Oboe.tracing?
            opts = {}

            opts[:Query] = 'BEGIN'
            Oboe::API.trace('activerecord', opts || {}) do
              begin_db_transaction_without_oboe
            end
          else
            begin_db_transaction_without_oboe
          end
        end
      end # Utils
    end
  end
end
