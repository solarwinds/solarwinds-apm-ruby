ActionController::Base.class_eval do
  alias :old_perform_action :perform_action
  alias :old_rescue_action :rescue_action

  def perform_action(*arguments)
    Oboe::Context.clear()

    xtrace_header = @_request.headers['X-Trace']
    event = nil

    if xtrace_header and Oboe.passthrough?
      Oboe::Context.fromString(xtrace_header)
    end

    if not Oboe::Context.isValid() and Oboe.always?
      evt = Oboe::Context.startTrace()
    elsif Oboe::Context.isValid() and not Oboe.never?
      evt = Oboe::Context.createEvent()
    end

    if evt
      evt.addInfo("Agent", "rails")
      evt.addInfo("Label", "entry")

      @_request.path_parameters.each_pair do |k, v|
        evt.addInfo(k.to_s.capitalize, v.to_s)
      end

      Oboe.reporter.sendReport(evt)

      endEvt = Oboe::Context.createEvent()
      @_response.headers['X-Trace'] = endEvt.metadataString()
    end

    begin
      begin
        result = old_perform_action(*arguments)
      rescue Exception => e
        Oboe::Context.log("rails", "error", { :message => e.message })
        raise
      end
    ensure
      if Oboe::Context.isValid() and endEvt
        evt = endEvt

        evt.addEdge(Oboe::Context.get())
        evt.addInfo("Agent", "rails")
        evt.addInfo("Label", "exit")

        @_request.path_parameters.each_pair do |k, v|
          evt.addInfo(k.to_s.capitalize, v.to_s)
        end

        Oboe.reporter.sendReport(evt)

        endEvt = nil
      end

      Oboe::Context.clear()
    end
  end

  def rescue_action(exn)
    Oboe::Context.log("rails", "error", { :Message => exn.message, :ErrorBacktrace => exn.backtrace.join("\r\n") })
    old_rescue_action(exn)
  end

end
