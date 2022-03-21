# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    ##
    # SolarWindsAPM::Inst::Sequel
    #
    # The common (shared) methods used by the SolarWindsAPM Sequel instrumentation
    # across multiple modules/classes.
    #
    module Sequel
      ##
      # assign_kvs
      #
      # Given SQL and the options hash, this method extracts the interesting
      # bits for reporting to the AppOptics dashboard.
      #
      # kvs is a hash and we are taking advantage of using it by reference to
      # assign kvs to the exit event (important for trace injection)
      #
      def assign_kvs(sql, opts, kvs)
        unless sql.is_a?(String)
          kvs[:IsPreparedStatement] = true
        end

        if ::Sequel::VERSION > '4.36.0' && !sql.is_a?(String)
          # TODO check if this is true for all sql
          # In 4.37.0, sql was converted to a prepared statement object
          sql = sql.prepared_sql unless sql.is_a?(Symbol)
        end

        if SolarWindsAPM::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          if sql.is_a?(Symbol)
            kvs[:Query] = sql
          else
            sql = SolarWindsAPM::Util.remove_traceparent(sql)
            kvs[:Query] = SolarWindsAPM::Util.sanitize_sql(sql)
          end
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = SolarWindsAPM::Util.remove_traceparent(sql.to_s)
          kvs[:QueryArgs] = opts[:arguments] if opts.is_a?(Hash) && opts.key?(:arguments)
        end

        kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:sequel][:collect_backtraces]

        if ::Sequel::VERSION < '3.41.0' && !(self.class.to_s =~ /Dataset$/)
          db_opts = @opts
        elsif @pool
          db_opts = @pool.db.opts
        else
          db_opts = @db.opts
        end

        kvs[:Database]   = db_opts[:database]
        kvs[:RemoteHost] = db_opts[:host]
        kvs[:RemotePort] = db_opts[:port] if db_opts.key?(:port)
        kvs[:Flavor]     = db_opts[:adapter]
      rescue => e
        SolarWindsAPM.logger.debug "[appoptics_apm/debug Error capturing Sequel KVs: #{e.message}" if SolarWindsAPM::Config[:verbose]
      end

      ##
      # exec_with_appoptics
      #
      # This method wraps and routes the call to the specified
      # original method call
      #
      def exec_with_appoptics(method, sql, opts = ::Sequel::OPTS, &block)
        kvs = {}
        SolarWindsAPM::SDK.trace(:sequel, kvs: kvs) do
          new_sql = add_traceparent(sql, kvs)
          assign_kvs(new_sql, opts, kvs) if SolarWindsAPM.tracing?
          send(method, new_sql, opts, &block)
        end
      end

      def add_traceparent(sql, kvs)
        return sql unless SolarWindsAPM.tracing? && SolarWindsAPM::Config[:tag_sql]

        case sql
        when String
          return SolarWindsAPM::SDK.current_trace_info.add_traceparent_to_sql(sql, kvs)
        when Symbol
          if defined?(prepared_statement) # for mysql2
            ps = prepared_statement(sql)
            new_ps = add_traceparent_to_ps(ps, kvs)
            set_prepared_statement(sql, new_ps)
            return sql # related query may have been modified
          elsif self.is_a?(::Sequel::Dataset) # for postgresql
            ps = self
            new_ps = add_traceparent_to_ps(ps, kvs)
            self.db.set_prepared_statement(sql, new_ps)
            return sql
          end
        when ::Sequel::Dataset::ArgumentMapper # for mysql2
          new_sql = add_traceparent_to_ps(sql, kvs)
          return new_sql # related query may have been modified
        end
        sql # return original when none of the cases match
      end

      # this method uses some non-api methods partially copied from
      # `execute_prepared_statement` in `mysql2.rb`
      # and `prepare` in `prepared_statements.rb` in the sequel gem
      def add_traceparent_to_ps(ps, kvs)
        sql = ps.prepared_sql
        new_sql = SolarWindsAPM::SDK.current_trace_info.add_traceparent_to_sql(sql, kvs)

        unless new_sql == sql
          new_ps = ps.clone(:prepared_sql=>new_sql, :sql=>new_sql)
          return new_ps
        end

        ps # no change, no trace context added
      end
    end

    module SequelDatabase
      include SolarWindsAPM::Inst::Sequel

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :run, ::Sequel::Database)
        SolarWindsAPM::Util.method_alias(klass, :execute_ddl, ::Sequel::Database)
        SolarWindsAPM::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        SolarWindsAPM::Util.method_alias(klass, :execute_insert, ::Sequel::Database)
      end

      def run_with_appoptics(sql, opts = ::Sequel::OPTS)
        kvs = {}
        SolarWindsAPM::SDK.trace(:sequel, kvs: kvs) do
          new_sql = add_traceparent(sql, kvs)
          assign_kvs(new_sql, opts, kvs) if SolarWindsAPM.tracing?
          run_without_appoptics(new_sql, opts)
        end
      end

      def execute_ddl_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_ddl_without_appoptics(sql, opts, &block) if SolarWindsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_ddl_without_appoptics, sql, opts, &block)
      end

      def execute_dui_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_dui_without_appoptics(sql, opts, &block) if SolarWindsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_dui_without_appoptics, sql, opts, &block)
      end

      def execute_insert_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_insert_without_appoptics(sql, opts, &block) if SolarWindsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_insert_without_appoptics, sql, opts, &block)
      end
    end # module SequelDatabase

    module AdapterDatabase
      include SolarWindsAPM::Inst::Sequel

      def self.included(klass)
        if defined?(::Sequel::MySQL::MysqlMysql2::DatabaseMethods)
          SolarWindsAPM::Util.method_alias(klass, :execute, ::Sequel::MySQL::MysqlMysql2::DatabaseMethods)
        end
        if defined?(::Sequel::Postgres::Database)
          SolarWindsAPM::Util.method_alias(klass, :execute, ::Sequel::Postgres::Database)
        end
      end

      def execute_with_appoptics(*args, &block)
        # if this is called via a dataset it is already being traced
        return execute_without_appoptics(*args, &block) if SolarWindsAPM.tracing_layer?(:sequel)

        kvs = {}
        SolarWindsAPM::SDK.trace(:sequel, kvs: kvs) do
          new_sql = add_traceparent(args[0], kvs)
          args[0] = new_sql
          assign_kvs(args[0], args[1], kvs) if SolarWindsAPM.tracing?
          execute_without_appoptics(*args, &block)
        end
      end
    end

    module SequelDataset
      include SolarWindsAPM::Inst::Sequel

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :execute, ::Sequel::Dataset)
        SolarWindsAPM::Util.method_alias(klass, :execute_ddl, ::Sequel::Dataset)
        SolarWindsAPM::Util.method_alias(klass, :execute_dui, ::Sequel::Dataset)
        SolarWindsAPM::Util.method_alias(klass, :execute_insert, ::Sequel::Dataset)
      end

      def execute_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        exec_with_appoptics(:execute_without_appoptics, sql, opts, &block)
      end

      def execute_ddl_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        exec_with_appoptics(:execute_ddl_without_appoptics, sql, opts, &block)
      end

      def execute_dui_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        exec_with_appoptics(:execute_dui_without_appoptics, sql, opts, &block)
      end

      def execute_insert_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        exec_with_appoptics(:execute_insert_without_appoptics, sql, opts, &block)
      end

    end # module SequelDataset
  end # module Inst
end # module SolarWindsAPM

if SolarWindsAPM::Config[:sequel][:enabled]
  if defined?(::Sequel) && ::Sequel::VERSION < '4.0.0'
    # For versions before 4.0.0, Sequel::OPTS wasn't defined.
    # Define it as an empty hash for backwards compatibility.
    module ::Sequel
      OPTS = {}
    end
  end

  if defined?(::Sequel)
    SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting sequel' if SolarWindsAPM::Config[:verbose]
    SolarWindsAPM::Util.send_include(::Sequel::Database, SolarWindsAPM::Inst::SequelDatabase)
    SolarWindsAPM::Util.send_include(::Sequel::Dataset, SolarWindsAPM::Inst::SequelDataset)

    # TODO this is temporary, we need to instrument `require`, see NH-9711
    require 'sequel/adapters/mysql2'
    SolarWindsAPM::Util.send_include(::Sequel::MySQL::MysqlMysql2::DatabaseMethods, SolarWindsAPM::Inst::AdapterDatabase)
    require 'sequel/adapters/postgres'
    SolarWindsAPM::Util.send_include(::Sequel::Postgres::Database, SolarWindsAPM::Inst::AdapterDatabase)
  end
end
