module Oboe
  def self.passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end

  def self.always?
    Oboe::Config[:tracing_mode] == "always"
  end

  def self.through?
    Oboe::Config[:tracing_mode] == "through"
  end

  def self.never?
    Oboe::Config[:tracing_mode] == "never"
  end

  def self.now?
    Oboe::Context.isValid and not Oboe.never?
  end

  def self.start?
    not Oboe::Context.isValid and Oboe.always?
  end

  def self.continue?
    Oboe::Context.isValid and not Oboe.never?
  end

  module Inst
    def self.trace_agent_block(agent, opts) 
      if Oboe.now?
        Oboe::Context.log(agent, 'entry', opts)
      end

      begin
        result = yield
      ensure
        if Oboe.now?
          evt = Oboe::Context.createEvent()
          evt.addInfo('Agent', agent)
          evt.addInfo('Label', 'exit')
          Oboe.reporter.sendReport(evt)
        end
      end

      return result
    end

    def self.log(agent, label, opts)
      if Oboe.now?
        evt = Oboe::Context.createEvent
        evt.addInfo('Agent', agent)
        evt.addInfo('Label', label)

        opts.each do |k, v|
          evt.addInfo(k.to_s, v.to_s)
        end

        Oboe.reporter.sendReport(evt)
      end
    end
  end
end
