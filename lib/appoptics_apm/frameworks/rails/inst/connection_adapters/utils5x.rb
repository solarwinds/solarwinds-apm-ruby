# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module ConnectionAdapters
      module Utils

        def extract_trace_details(sql, name = nil, binds = [])
          kvs = {}

          begin
            if AppOpticsAPM::Config[:sanitize_sql]
              # Sanitize SQL and don't report binds
              kvs[:Query] = AppOpticsAPM::Util.sanitize_sql(sql)
            else
              # Report raw SQL and any binds if they exist
              kvs[:Query] = sql.to_s
              if binds && !binds.empty?
                kvs[:QueryArgs] = binds.map(&:value)
              end
            end

            kvs[:Name] = name.to_s if name
            if AppOpticsAPM::Config[:active_record] && AppOpticsAPM::Config[:active_record][:collect_backtraces]
              kvs[:Backtrace] = AppOpticsAPM::API.backtrace
            end

            if ActiveRecord::Base.respond_to?(:connection_db_config)
              config = ActiveRecord::Base.connection_db_config.configuration_hash
            else
              config = ActiveRecord::Base.connection_config
            end

            if config
              kvs[:Database] = config[:database] if config.key?(:database)
              kvs[:RemoteHost] = config[:host] if config.key?(:host)
              adapter_name = config[:adapter]

              case adapter_name
              when /mysql/i
                kvs[:Flavor] = 'mysql'
              when /^postgres|^postgis/i
                kvs[:Flavor] = 'postgresql'
              end
            end
          rescue StandardError => e
            AppOpticsAPM.logger.debug "[appoptics_apm/rails] Exception raised capturing ActiveRecord KVs: #{e.inspect}"
            AppOpticsAPM.logger.debug e.backtrace.join('\n')
          end

          kvs
        end

        # We don't want to trace framework caches.  Only instrument SQL that
        # directly hits the database.
        def ignore_payload?(name)
          %w(SCHEMA EXPLAIN CACHE).include?(name.to_s) ||
            (name && name.to_sym == :skip_logging) ||
            name == 'ActiveRecord::SchemaMigration Load'
        end

        def exec_query_with_appoptics(sql, name = nil, binds = [], prepare: false)
          if AppOpticsAPM.tracing? && !AppOpticsAPM.tracing_layer_op?(:ar_started) && !ignore_payload?(name)

            kvs = extract_trace_details(sql, name, binds)
            AppOpticsAPM::SDK.trace('activerecord', kvs: kvs) do
              exec_query_without_appoptics(sql, name, binds)
            end
          else
            exec_query_without_appoptics(sql, name, binds)
          end
        end

        def exec_insert_with_appoptics(sql, name = nil, binds = [], *args)
          if AppOpticsAPM.tracing? && !ignore_payload?(name)

            kvs = extract_trace_details(sql, name, binds)
            AppOpticsAPM::SDK.trace('activerecord', kvs: kvs, protect_op: :ar_started) do
              exec_insert_without_appoptics(sql, name, binds, *args)
            end
          else
            exec_insert_without_appoptics(sql, name, binds, *args)
          end
        end

        def exec_delete_with_appoptics(sql, name = nil, binds = [])
          if AppOpticsAPM.tracing? && !ignore_payload?(name)

            kvs = extract_trace_details(sql, name, binds)
            AppOpticsAPM::SDK.trace('activerecord', kvs: kvs, protect_op: :ar_started) do
              exec_delete_without_appoptics(sql, name, binds)
            end
          else
            exec_delete_without_appoptics(sql, name, binds)
          end
        end

        def exec_update_with_appoptics(sql, name = nil, binds = [])
          if AppOpticsAPM.tracing? && !ignore_payload?(name)

            kvs = extract_trace_details(sql, name, binds)
            AppOpticsAPM::SDK.trace('activerecord', kvs: kvs, protect_op: :ar_started) do
              exec_update_without_appoptics(sql, name, binds)
            end
          else
            exec_update_without_appoptics(sql, name, binds)
          end
        end
      end # Utils
    end
  end
end
