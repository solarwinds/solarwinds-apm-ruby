module Oboe
  module Inst
    module Sequel
      def extract_trace_details(sql, opts)
        kvs = {}

        if Oboe::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          if sql.is_a?(Symbol)
            kvs[:Query] = sql
          else
            kvs[:Query] = sql.gsub(/('[\s\S][^\']*\'|\d*\.\d*)/, '?')
          end
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = sql.to_s
          kvs[:QueryArgs] = opts[:arguments] if opts.is_a?(Hash) and opts.key?(:arguments)
        end
        kvs[:IsPreparedStatement] = true if sql.is_a?(Symbol)

        kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:sequel][:collect_backtraces]

        if @pool
          db_opts = @pool.db.opts
        else
          db_opts = @db.opts
        end

        kvs[:Database]   = db_opts[:database]
        kvs[:RemoteHost] = db_opts[:host]
        kvs[:RemotePort] = db_opts[:port] if db_opts.key?(:port)
        kvs[:Flavor]     = db_opts[:adapter]
      rescue => e
        Oboe.logger.debug "[oboe/debug Error capturing Sequel KVs: #{e.message}" if Oboe::Config[:verbose]
      ensure
        return kvs
      end
    end

    module SequelDatabase
      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :run, ::Sequel::Database)
        ::Oboe::Util.method_alias(klass, :execute, ::Sequel::Database)
        ::Oboe::Util.method_alias(klass, :execute_ddl, ::Sequel::Database)
        ::Oboe::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        ::Oboe::Util.method_alias(klass, :execute_insert, ::Sequel::Database)
      end

      def run_with_oboe(sql, opts=::Sequel::OPTS)
        kvs = extract_trace_details(sql, opts)

        Oboe::API.log_entry('sequel', kvs)

        run_without_oboe(sql, opts)
      rescue => e
        Oboe::API.log_exception('sequel', e)
        raise e
      ensure
        Oboe::API.log_exit('sequel')
      end

      def exec_with_oboe(method, sql, opts=::Sequel::OPTS, &block)
        kvs = extract_trace_details(sql, opts)

        Oboe::API.log_entry('sequel', kvs)

        send(method, sql, opts, &block)
      rescue => e
        Oboe::API.log_exception('sequel', e)
        raise e
      ensure
        Oboe::API.log_exit('sequel')
      end

      def execute_with_oboe(sql, opts=::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_without_oboe(sql, opts, &block) if Oboe.tracing_layer?('sequel')

        exec_with_oboe(:execute_without_oboe, sql, opts, &block)
      end

      def execute_ddl_with_oboe(sql, opts=::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_ddl_without_oboe(sql, opts, &block) if Oboe.tracing_layer?('sequel')

        exec_with_oboe(:execute_ddl_without_oboe, sql, opts, &block)
      end

      def execute_dui_with_oboe(sql, opts=::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_dui_without_oboe(sql, opts, &block) if Oboe.tracing_layer?('sequel')

        exec_with_oboe(:execute_dui_without_oboe, sql, opts, &block)
      end

      def execute_insert_with_oboe(sql, opts=::Sequel::OPTS, &block)
        # If we're already tracing a sequel operation, then this call likely came
        # from Sequel::Dataset.  In this case, just pass it on.
        return execute_insert_without_oboe(sql, opts, &block) if Oboe.tracing_layer?('sequel')

        exec_with_oboe(:execute_insert_without_oboe, sql, opts, &block)
      end
    end # module SequelDatabase

    module SequelDataset

      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :execute, ::Sequel::Dataset)
        ::Oboe::Util.method_alias(klass, :execute_ddl, ::Sequel::Dataset)
        ::Oboe::Util.method_alias(klass, :execute_dui, ::Sequel::Dataset)
        ::Oboe::Util.method_alias(klass, :execute_insert, ::Sequel::Dataset)
      end

      def exec_with_oboe(method, sql, opts=::Sequel::OPTS, &block)
        kvs = extract_trace_details(sql, opts)

        Oboe::API.log_entry('sequel', kvs)

        send(method, sql, opts, &block)
      rescue => e
        Oboe::API.log_exception('sequel', e)
        raise e
      ensure
        Oboe::API.log_exit('sequel')
      end

      def execute_with_oboe(sql, opts=::Sequel::OPTS, &block)
        exec_with_oboe(:execute_without_oboe, sql, opts, &block)
      end

      def execute_ddl_with_oboe(sql, opts=::Sequel::OPTS, &block)
        exec_with_oboe(:execute_ddl_without_oboe, sql, opts, &block)
      end

      def execute_dui_with_oboe(sql, opts=::Sequel::OPTS, &block)
        exec_with_oboe(:execute_dui_without_oboe, sql, opts, &block)
      end

      def execute_insert_with_oboe(sql, opts=::Sequel::OPTS, &block)
        exec_with_oboe(:execute_insert_without_oboe, sql, opts, &block)
      end

    end # module SequelDataset
  end # module Inst
end # module Oboe

if Oboe::Config[:sequel][:enabled]
  if defined?(::Sequel)
    Oboe.logger.info '[oboe/loading] Instrumenting sequel' if Oboe::Config[:verbose]
    ::Oboe::Util.send_include(::Sequel::Database, ::Oboe::Inst::Sequel)
    ::Oboe::Util.send_include(::Sequel::Database, ::Oboe::Inst::SequelDatabase)
    ::Oboe::Util.send_include(::Sequel::Dataset, ::Oboe::Inst::Sequel)
    ::Oboe::Util.send_include(::Sequel::Dataset, ::Oboe::Inst::SequelDataset)
  end
end
