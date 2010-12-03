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
