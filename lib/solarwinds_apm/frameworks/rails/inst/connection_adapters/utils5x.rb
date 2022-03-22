# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module ConnectionAdapters
      module Utils

        def exec_query_with_appoptics(*args, **args2)
          trace_wrap(*args) do |args|
            exec_query_without_appoptics(*args, **args2)
          end
        end

        # need to instrument them all
        def exec_insert_with_appoptics(*args)
          trace_wrap(*args) do |args|
            exec_insert_without_appoptics(*args)
          end
        end

        def exec_delete_with_appoptics(*args)
          trace_wrap(*args) do |args|
            exec_delete_without_appoptics(*args)
          end
        end

        def exec_update_with_appoptics(*args)
          trace_wrap(*args) do |args|
            exec_update_without_appoptics(*args)
          end
        end

        private

        def trace_wrap(*args)
          sql, name, binds, _ = args
          kvs = {}
          args[0] = SolarWindsAPM::SDK.current_trace_info.add_traceparent_to_sql(sql, kvs)
          if SolarWindsAPM.tracing? && !ignore_payload?(name)
            assign_kvs(sql, kvs, name, binds || [])
            # use protect_op to avoid double tracing in mysql2
            SolarWindsAPM::SDK.trace('activerecord', kvs: kvs, protect_op: :ar_started) do
              yield args
            end
          else
            yield args
          end
        end

        def assign_kvs(sql, kvs, name = nil, binds = [])
          sql = SolarWindsAPM::Util.remove_traceparent(sql.to_s)
          if SolarWindsAPM::Config[:sanitize_sql]
            # Sanitize SQL and don't report binds
            kvs[:Query] = SolarWindsAPM::Util.sanitize_sql(sql)
          else
            # Report raw SQL or name of statement and any binds if they exist
            kvs[:Query] = sql
            if binds && !binds.empty?
              kvs[:QueryArgs] = binds.map(&:value)
            end
          end

          kvs[:Name] = name.to_s if name
          if SolarWindsAPM::Config[:active_record] && SolarWindsAPM::Config[:active_record][:collect_backtraces]
            kvs[:Backtrace] = SolarWindsAPM::API.backtrace
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
          SolarWindsAPM.logger.debug "[solarwinds_apm/rails] Exception raised capturing ActiveRecord KVs: #{e.inspect}"
          SolarWindsAPM.logger.debug e.backtrace.join('\n')
        end

        # We don't want to trace framework caches.
        # Only instrument SQL that directly hits the database.
        def ignore_payload?(name)
          %w(SCHEMA EXPLAIN CACHE).include?(name.to_s) ||
            (name && name.to_sym == :skip_logging) ||
            name == 'ActiveRecord::SchemaMigration Load'
        end

      end # Utils
    end
  end
end
