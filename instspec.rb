module Oboe
  module Instrumentation
    def self.log(layer, label, opts={})
      self.log_event(layer, label, Oboe::Context.createEvent, opts)
    end

    def self.log_start(layer, xtrace, opts={})
      return if Oboe.never?

      if xtrace
        Oboe::Context.fromString(xtrace)
      end

      if Oboe.tracing?
        self.log_entry(layer, opts)
      elsif Oboe.start?
        self.log_event(layer, 'entry', Oboe::Context.startTrace, opts)
      end
    end

    def self.log_end(layer, opts={})
      self.log_event(layer, 'exit', Oboe::Context.createEvent, opts)
      xtrace = Oboe::Context.toString
      Oboe::Context.clear
      xtrace
    end

    def self.log_entry(layer, opts={})
      self.log_event(layer, 'entry', Oboe::Context.createEvent, opts)
    end

    def self.log_exit(layer, opts={})
      self.log_event(layer, 'exit', Oboe::Context.createEvent, opts)
    end

    def self.log_event(layer, label, event, opts={})
      event.addInfo('Layer', layer.to_s)
      event.addInfo('Label', label.to_s)

      opts.each do | k, v|
        event.addInfo(k.to_s, v.to_s) if valid_key? k
      end if opts.any?

      Oboe.reporter.sendReport(event)
    end

    def self.trace(layer, opts={})
      log_entry(layer, opts)
      result = yield
      log_exit(layer)
      result
    end

    def self.start_trace(layer, opts={})
      log_start(layer, nil, opts)
      result = yield
      xtrace = log_end(layer)
      result, xtrace
    end

    def self.valid_key?(k)
      not ['Label', 'Layer', 'Edge', 'Timestamp', 'Timestamp_u'].include? k.to_s
    end
  end
end
