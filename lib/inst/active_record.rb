if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
  ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
    def cfg
      @config
    end
  end
end

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
    def cfg
      @config
    end
  end
end

ActiveRecord::Base.class_eval do
  class << self
    alias old_find_by_sql find_by_sql

    def find_by_sql(query, *arguments)
      tracing_mode = Oboe::Config[:tracing_mode]

      if Oboe::Context.isValid() and tracing_mode != "never"
        evt = Oboe::Context.createEvent()
        evt.addInfo("Agent", "ActiveRecord")
        evt.addInfo("Label", "entry")
        evt.addInfo("Query",  query.to_s)

        if defined?(ActiveRecord::Base.connection.cfg)
          # Note that changing databases will break this
          evt.addInfo("Database", ActiveRecord::Base.connection.cfg[:database])
        end

        evt.addInfo("Backtrace", Kernel.caller.join("\r\n"))

        Oboe.reporter.sendReport(evt)
      end

      begin
        result = old_find_by_sql(query, *arguments)
      ensure
        if Oboe::Context.isValid() and tracing_mode != "never"
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
