require 'byebug'

module Oboe
  module Inst
    module Sequel

      def self.included(klass)
        ::Oboe::Util.method_alias(klass, :execute_dui, ::Sequel::Database)
        ::Oboe::Util.method_alias(klass, :get, ::Sequel::Database)
      end

      def extract_trace_details(sql, opts)
        kvs = {}

        if Oboe::Config[:sanitize_sql]
          # Sanitize SQL and don't report binds
          kvs[:Query] = sql.gsub(/\'[\s\S][^\']*\'/, '?')
        else
          # Report raw SQL and any binds if they exist
          kvs[:Query] = sql.to_s
        end

        kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:active_record][:collect_backtraces]

        #kvs[:Database]   = 
        #kvs[:RemoteHost] = 
        #kvs[:Flavor]     = 
        kvs
      end

      def execute_dui_with_oboe(sql, opts=::Sequel::OPTS, &block)
        kvs = extract_trace_details(sql, opts)

        Oboe::API.log_entry('sequel', kvs)

        result = execute_dui_without_oboe(sql, opts, &block)
      rescue => e
        Oboe::API.log_exception('sequel', e)
        raise e
      ensure
        Oboe::API.log_exit('sequel')
      end

      def get_with_oboe(*args, &block)
        kvs = extract_trace_details(sql, opts)

        Oboe::API.log_entry('sequel', kvs)

        result = run_without_oboe(sql, opts)
      rescue => e
        Oboe::API.log_exception('sequel', e)
        raise e
      ensure
        Oboe::API.log_exit('sequel')
      end
    end
  end
end

if Oboe::Config[:sequel][:enabled]
  if defined?(::Sequel)
    Oboe.logger.info '[oboe/loading] Instrumenting sequel' if Oboe::Config[:verbose]
    ::Oboe::Util.send_include(::Sequel::Database, ::Oboe::Inst::Sequel)
  end
end
