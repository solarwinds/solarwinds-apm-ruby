module Oboe
  module Inst
    module ConnectionAdapters
      def self.included(cls)
        cls.class_eval do
          alias unwrapped_execute execute
          alias execute wrapped_execute
        end
      end

      def wrapped_execute(sql, name = nil)
        tracing_mode = Oboe::Config[:tracing_mode]

        if Oboe::Context.isValid() and tracing_mode != "never" and name and name != :skip_logging
          evt = Oboe::Context.createEvent()
          evt.addInfo("Agent", "ActiveRecord")
          evt.addInfo("Label", "entry")
          evt.addInfo("Query", sql.to_s)
          evt.addInfo("Name", name.to_s)

          if defined?(ActiveRecord::Base.connection.cfg)
            # Note that changing databases will break this
            evt.addInfo("Database", ActiveRecord::Base.connection.cfg[:database])
            evt.addInfo("RemoteHost", ActiveRecord::Base.connection.cfg[:host])
          end

          if defined?(ActiveRecord::Base.connection.sql_flavor)
            evt.addInfo("Flavor", ActiveRecord::Base.connection.sql_flavor)
          end

          evt.addInfo("Backtrace", Kernel.caller.join("\r\n"))

          Oboe.reporter.sendReport(evt)
        end

        begin
          result = unwrapped_execute(sql, name)
        ensure
          if Oboe::Context.isValid() and tracing_mode != "never" and name and name != :skip_logging
            evt = Oboe::Context.createEvent()
            evt.addInfo("Agent", "ActiveRecord")
            evt.addInfo("Label", "exit")

            Oboe.reporter.sendReport(evt)
          end
        end

        return result
      end
    end
  end
end

if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
  ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
    include Oboe::Inst::ConnectionAdapters

    def cfg
      @config
    end

    def sql_flavor
      'mysql'
    end
  end
end


if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
  ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
    include Oboe::Inst::ConnectionAdapters

    def cfg
      @config
    end

    def sql_flavor
      'mysql'
    end
  end
end

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
    include Oboe::Inst::ConnectionAdapters

    def cfg
      @config
    end

    def sql_flavor
      'postgresql'
    end
  end
end
