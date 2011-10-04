module Oboe
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Oboe::Context.clear()

      hdr = env['HTTP_X_TRACE']

      if hdr and Oboe.passthrough?
        Oboe::Context.fromString(hdr)
      end


      # short circuit-the rest
      if not (Oboe.start? or Oboe.continue?)
        return @app.call(env)
      end

      if Oboe.start?
        entryEvt = Oboe::Context.startTrace()
      elsif Oboe.continue?
        entryEvt = Oboe::Context.createEvent()
      end

      entryEvt.addInfo('Layer', 'rack')
      entryEvt.addInfo('Label', 'entry')
      Oboe.reporter.sendReport(entryEvt)
      exitEvt = Oboe::Context.createEvent()

      begin
        env['HTTP_X_TRACE'] = Oboe::Context.toString
        status, headers, body = @app.call(env)

        Oboe::Context.fromString(headers['X-Trace']) if headers['X-Trace']

        exitEvt.addEdge(Oboe::Context.get())
        headers['X-Trace'] = exitEvt.metadataString

        return [status, headers, body]
      ensure
        exitEvt.addInfo('Layer', 'rack')
        exitEvt.addInfo('Label', 'exit')
        Oboe.reporter.sendReport(exitEvt)
        Oboe::Context.clear()
      end
    end
  end
end

if defined?(Rails.configuration.middleware)
  puts "[oboe_fu/loading] Instrumenting rack"
  Rails.configuration.middleware.insert 0, Oboe::Middleware
end
