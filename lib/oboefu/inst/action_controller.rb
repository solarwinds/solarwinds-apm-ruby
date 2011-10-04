if defined?(ActionController) and defined?(ActionController::Base)
  ActionController::Base.class_eval do
    alias :old_perform_action :perform_action
    alias :old_rescue_action :rescue_action

    def perform_action(*arguments)
      Oboe::Context.clear()

      hdr = @_request.headers['X-Trace']

      if hdr and Oboe.passthrough?
        Oboe::Context.fromString(hdr)
      end

      if not (Oboe.start? or Oboe.continue?)
        return old_perform_action(*arguments)
      end

      if Oboe.start?
        entryEvt = Oboe::Context.startTrace()
      elsif Oboe.continue?
        entryEvt = Oboe::Context.createEvent()
      end

      entryEvt.addInfo("Layer", "rails")
      entryEvt.addInfo("Label", "entry")
      @_request.path_parameters.each_pair do |k, v|
        entryEvt.addInfo(k.to_s.capitalize, v.to_s)
      end
      Oboe.reporter.sendReport(entryEvt)

      exitEvt = Oboe::Context.createEvent()
      @_response.headers['X-Trace'] = exitEvt.metadataString()

      begin
        result = old_perform_action(*arguments)
      rescue Exception => e
        Oboe::Inst.log_exception('rails', e)
        raise
      end
    ensure
      if Oboe::Context.isValid() and exitEvt
        exitEvt.addEdge(Oboe::Context.get())
        exitEvt.addInfo("Layer", "rails")
        exitEvt.addInfo("Label", "exit")

        @_request.path_parameters.each_pair do |k, v|
          exitEvt.addInfo(k.to_s.capitalize, v.to_s)
        end

        Oboe::Context.clear()
      end
    end

    def rescue_action(exn)
      Oboe::Inst.log_exception('rails', exn)
      old_rescue_action(exn)
    end

  end
end
