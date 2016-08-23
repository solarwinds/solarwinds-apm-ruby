# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    ##
    # TraceView::Inst::Sequel
    #
    # The common (shared) methods used by the TraceView Sequel instrumentation
    # across multiple modules/classes.
    #
    module Sequel
      ##
      # extract_trace_details
      #
      # Given SQL and the options hash, this method extracts the interesting
      # bits for reporting to the TraceView dashboard.
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

        if TraceView::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          if sql.is_a?(Symbol)
            kvs[:Query] = sql
          else
            kvs[:Query] = TraceView::Util.sanitize_sql(sql)
          end
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = sql.to_s
          kvs[:QueryArgs] = opts[:arguments] if opts.is_a?(Hash) && opts.key?(:arguments)
        end

        kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:sequel][:collect_backtraces]

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
        TraceView.logger.debug "[traceview/debug Error capturing Sequel KVs: #{e.message}" if TraceView::Config[:verbose]
      ensure
        return kvs
      end

      ##
      # exec_with_traceview
      #
      # This method wraps and routes the call to the specified
      # original method call
      #
      def exec_with_traceview(method, sql, opts = ::Sequel::OPTS, &block)
        kvs = extract_trace_details(sql, opts)

        TraceView::API.log_entry(:sequel, kvs)

        send(method, sql, opts, &block)
      rescue => e
        TraceView::API.log_exception(:sequel, e)
        raise e
      ensure
        TraceView::API.log_exit(:sequel)
      end
    end

    module SequelDatabase
      include TraceView::Inst::Sequel

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :run, ::Sequel::Database)
        ::TraceView::Util.method_alias(klass, :execute_ddl, ::Sequel::Database)
        ::TraceView::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        ::TraceView::Util.method_alias(klass, :execute_insert, ::Sequel::Database)
      end

      def run_with_traceview(sql, opts = ::Sequel::OPTS)
        kvs = extract_trace_details(sql, opts)

        TraceView::API.log_entry(:sequel, kvs)

        run_without_traceview(sql, opts)
      rescue => e
        TraceView::API.log_exception(:sequel, e)
        raise e
      ensure
        TraceView::API.log_exit(:sequel)
      end

      def execute_ddl_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_ddl_without_traceview(sql, opts, &block) if TraceView.tracing_layer?(:sequel)

        exec_with_traceview(:execute_ddl_without_traceview, sql, opts, &block)
      end

      def execute_dui_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_dui_without_traceview(sql, opts, &block) if TraceView.tracing_layer?(:sequel)

        exec_with_traceview(:execute_dui_without_traceview, sql, opts, &block)
      end

      def execute_insert_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_insert_without_traceview(sql, opts, &block) if TraceView.tracing_layer?(:sequel)

        exec_with_traceview(:execute_insert_without_traceview, sql, opts, &block)
      end
    end # module SequelDatabase

    module SequelDataset
      include TraceView::Inst::Sequel

      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :execute, ::Sequel::Dataset)
        ::TraceView::Util.method_alias(klass, :execute_ddl, ::Sequel::Dataset)
        ::TraceView::Util.method_alias(klass, :execute_dui, ::Sequel::Dataset)
        ::TraceView::Util.method_alias(klass, :execute_insert, ::Sequel::Dataset)
      end

      def execute_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        exec_with_traceview(:execute_without_traceview, sql, opts, &block)
      end

      def execute_ddl_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        exec_with_traceview(:execute_ddl_without_traceview, sql, opts, &block)
      end

      def execute_dui_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        exec_with_traceview(:execute_dui_without_traceview, sql, opts, &block)
      end

      def execute_insert_with_traceview(sql, opts = ::Sequel::OPTS, &block)
        exec_with_traceview(:execute_insert_without_traceview, sql, opts, &block)
      end

    end # module SequelDataset
  end # module Inst
end # module TraceView

if TraceView::Config[:sequel][:enabled]
  if defined?(::Sequel) && ::Sequel::VERSION < '4.0.0'
    # For versions before 4.0.0, Sequel::OPTS wasn't defined.
    # Define it as an empty hash for backwards compatibility.
    module ::Sequel
      OPTS = {}
    end
  end

  if defined?(::Sequel)
    TraceView.logger.info '[traceview/loading] Instrumenting sequel' if TraceView::Config[:verbose]
    ::TraceView::Util.send_include(::Sequel::Database, ::TraceView::Inst::SequelDatabase)
    ::TraceView::Util.send_include(::Sequel::Dataset, ::TraceView::Inst::SequelDataset)
  end
end
