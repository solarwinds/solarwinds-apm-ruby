# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module ConnectionAdapters
      def self.included(cls)
        cls.class_eval do
          alias execute_without_oboe execute
          alias execute execute_with_oboe
        end
      end

      def execute_with_oboe(sql, name = nil)
        if Oboe::Config.tracing?
          opts = { :Query => sql.to_s, :Name => name.to_s }
          if defined?(ActiveRecord::Base.connection.cfg)
            opts[:Database] = ActiveRecord::Base.connection.cfg[:database]
            opts[:RemoteHost] = ActiveRecord::Base.connection.cfg[:host]
          end

          if defined?(ActiveRecord::Base.connection.sql_flavor)
            opts[:Flavor] = ActiveRecord::Base.connection.sql_flavor
          end
        end

        Oboe::API.trace('ActiveRecord', opts || {}) do
          execute_without_oboe(sql, name)
        end
      end

      def cfg
        @config
      end

      module FlavorInitializers
        def self.mysql
          if defined?(::ActiveRecord::ConnectionAdapters::MysqlAdapter)
            puts "[oboe_fu/loading] Instrumenting ActiveRecord MysqlAdapter"
            ::ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
              include ::Oboe::Inst::ConnectionAdapters

              def sql_flavor
                'mysql'
              end
            end
          end
        end

        def self.mysql2
          if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
            puts "[oboe_fu/loading] Instrumenting ActiveRecord Mysql2Adapter"
            ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
              include Oboe::Inst::ConnectionAdapters

              def sql_flavor
                'mysql'
              end
            end
          end
        end

        def self.postgresql
          if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
            puts "[oboe_fu/loading] Instrumenting ActiveRecord PostgreSQLAdapter"
            ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters

              def sql_flavor
                'postgresql'
              end
            end
          end
        end

        def self.oracle
          if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
            puts "[oboe_fu/loading] Instrumenting ActiveRecord OracleEnhancedAdapter"
            ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.module_eval do
              include Oboe::Inst::ConnectionAdapters

              def sql_flavor
                'oracle'
              end
            end
          end
        end
      end

    end
  end
end

if Rails::VERSION::MAJOR == 3
  Rails.configuration.after_initialize do
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql
    Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle
  end
else
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.mysql2
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.postgresql
  Oboe::Inst::ConnectionAdapters::FlavorInitializers.oracle
end
