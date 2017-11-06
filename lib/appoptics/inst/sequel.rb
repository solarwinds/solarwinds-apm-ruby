# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    ##
    # AppOptics::Inst::Sequel
    #
    # The common (shared) methods used by the AppOptics Sequel instrumentation
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
          # In 4.37.0, sql was converted to a prepared statement object
          sql = sql.prepared_sql unless sql.is_a?(Symbol)
        end

        if AppOptics::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          if sql.is_a?(Symbol)
            kvs[:Query] = sql
          else
            kvs[:Query] = AppOptics::Util.sanitize_sql(sql)
          end
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = sql.to_s
          kvs[:QueryArgs] = opts[:arguments] if opts.is_a?(Hash) && opts.key?(:arguments)
        end

        kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:sequel][:collect_backtraces]

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
        AppOptics.logger.debug "[appoptics/debug Error capturing Sequel KVs: #{e.message}" if AppOptics::Config[:verbose]
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
        kvs = extract_trace_details(sql, opts)

        AppOptics::API.log_entry(:sequel, kvs)

        send(method, sql, opts, &block)
      rescue => e
        AppOptics::API.log_exception(:sequel, e)
        raise e
      ensure
        AppOptics::API.log_exit(:sequel)
      end
    end

    module SequelDatabase
      include AppOptics::Inst::Sequel

      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :run, ::Sequel::Database)
        ::AppOptics::Util.method_alias(klass, :execute_ddl, ::Sequel::Database)
        ::AppOptics::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        ::AppOptics::Util.method_alias(klass, :execute_insert, ::Sequel::Database)
      end

      def run_with_appoptics(sql, opts = ::Sequel::OPTS)
        kvs = extract_trace_details(sql, opts)

        AppOptics::API.log_entry(:sequel, kvs)

        run_without_appoptics(sql, opts)
      rescue => e
        AppOptics::API.log_exception(:sequel, e)
        raise e
      ensure
        AppOptics::API.log_exit(:sequel)
      end

      def execute_ddl_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_ddl_without_appoptics(sql, opts, &block) if AppOptics.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_ddl_without_appoptics, sql, opts, &block)
      end

      def execute_dui_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_dui_without_appoptics(sql, opts, &block) if AppOptics.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_dui_without_appoptics, sql, opts, &block)
      end

      def execute_insert_with_appoptics(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_insert_without_appoptics(sql, opts, &block) if AppOptics.tracing_layer?(:sequel)

        exec_with_appoptics(:execute_insert_without_appoptics, sql, opts, &block)
      end
    end # module SequelDatabase

    module SequelDataset
      include AppOptics::Inst::Sequel

      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :execute, ::Sequel::Dataset)
        ::AppOptics::Util.method_alias(klass, :execute_ddl, ::Sequel::Dataset)
        ::AppOptics::Util.method_alias(klass, :execute_dui, ::Sequel::Dataset)
        ::AppOptics::Util.method_alias(klass, :execute_insert, ::Sequel::Dataset)
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
end # module AppOptics

if AppOptics::Config[:sequel][:enabled]
  if defined?(::Sequel) && ::Sequel::VERSION < '4.0.0'
    # For versions before 4.0.0, Sequel::OPTS wasn't defined.
    # Define it as an empty hash for backwards compatibility.
    module ::Sequel
      OPTS = {}
    end
  end

  if defined?(::Sequel)
    AppOptics.logger.info '[appoptics/loading] Instrumenting sequel' if AppOptics::Config[:verbose]
    ::AppOptics::Util.send_include(::Sequel::Database, ::AppOptics::Inst::SequelDatabase)
    ::AppOptics::Util.send_include(::Sequel::Dataset, ::AppOptics::Inst::SequelDataset)
  end
end
