# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    ##
    # AppOpticsAPM::Inst::Sequel
    #
    # The common (shared) methods used by the AppOpticsAPM Sequel instrumentation
    # across multiple modules/classes.
    #
    module Sequel
      ##
      # extract_trace_details
      #
      # Given SQL and the options hash, this method extracts the interesting
      # bits for reporting to the AppOptics dashboard.
      #
      def extract_trace_details(sql, opts)
        kvs = {}

        if !sql.is_a?(String)
          kvs[:IsPreparedStatement] = true
        end

        if ::Sequel::VERSION > '4.36.0' && !sql.is_a?(String)
          # TODO check if this is true for all sql
          # In 4.37.0, sql was converted to a prepared statement object
          sql = sql.prepared_sql unless sql.is_a?(Symbol)
        end

        if AppOpticsAPM::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          if sql.is_a?(Symbol)
            kvs[:Query] = sql
          else
            kvs[:Query] = AppOpticsAPM::Util.sanitize_sql(sql)
          end
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = sql.to_s
          kvs[:QueryArgs] = opts[:arguments] if opts.is_a?(Hash) && opts.key?(:arguments)
        end

        kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:sequel][:collect_backtraces]

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
        AppOpticsAPM.logger.debug "[appoptics_apm/debug Error capturing Sequel KVs: #{e.message}" if AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      ##
      # exec_with_appoptics
      #
      # This method wraps and routes the call to the specified
      # original method call
      #
      def exec_with_appoptics(method, sql, opts = ::Sequel::OPTS, &block)
        if AppOpticsAPM.tracing?
          kvs = extract_trace_details(sql, opts)
          AppOpticsAPM::API.log_entry(:sequel, kvs)
        end

        send(method, sql, opts, &block)
      rescue => e
        AppOpticsAPM::API.log_exception(:sequel, e)
        raise e
      ensure
        AppOpticsAPM::API.log_exit(:sequel)
      end
    end

    module SequelDatabase
      include AppOpticsAPM::Inst::Sequel

      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :run, ::Sequel::Database)
        AppOpticsAPM::Util.method_alias(klass, :execute_ddl, ::Sequel::Database)
        AppOpticsAPM::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        AppOpticsAPM::Util.method_alias(klass, :execute_insert, ::Sequel::Database)
      end

      def run_with_appoptics(sql, opts = ::Sequel::OPTS)
        if AppOpticsAPM.tracing?
          kvs = extract_trace_details(sql, opts)
          AppOpticsAPM::API.log_entry(:sequel, kvs)
        end

        run_without_appoptics(sql, opts)
      rescue => e
        AppOpticsAPM::API.log_exception(:sequel, e)
        raise e
      ensure
        AppOpticsAPM::API.log_exit(:sequel)
      end

      def execute_ddl_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_ddl_without_appoptics(sql, opts, &block) if AppOpticsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_ddl_without_appoptics, sql, opts, &block)
      end

      def execute_dui_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_dui_without_appoptics(sql, opts, &block) if AppOpticsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_dui_without_appoptics, sql, opts, &block)
      end

      def execute_insert_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_insert_without_appoptics(sql, opts, &block) if AppOpticsAPM.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_insert_without_appoptics, sql, opts, &block)
      end
    end # module SequelDatabase

    module SequelDataset
      include AppOpticsAPM::Inst::Sequel

      def self.included(klass)
        AppOpticsAPM::Util.method_alias(klass, :execute, ::Sequel::Dataset)
        AppOpticsAPM::Util.method_alias(klass, :execute_ddl, ::Sequel::Dataset)
        AppOpticsAPM::Util.method_alias(klass, :execute_dui, ::Sequel::Dataset)
        AppOpticsAPM::Util.method_alias(klass, :execute_insert, ::Sequel::Dataset)
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
end # module AppOpticsAPM

if AppOpticsAPM::Config[:sequel][:enabled]
  if defined?(::Sequel) && ::Sequel::VERSION < '4.0.0'
    # For versions before 4.0.0, Sequel::OPTS wasn't defined.
    # Define it as an empty hash for backwards compatibility.
    module ::Sequel
      OPTS = {}
    end
  end

  if defined?(::Sequel)
    AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting sequel' if AppOpticsAPM::Config[:verbose]
    AppOpticsAPM::Util.send_include(::Sequel::Database, AppOpticsAPM::Inst::SequelDatabase)
    AppOpticsAPM::Util.send_include(::Sequel::Dataset, AppOpticsAPM::Inst::SequelDataset)
  end
end
