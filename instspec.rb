module Oboe
  module Instrumentation
    def self.log(layer, label, opts={})
      self.log_event(layer, label, Oboe::Context.createEvent, opts)
    end

    def self.log_exception(layer, exn)
      log(layer, 'error', {
        :ErrorClass => exn.class.name,
        :Message => exn.message,
        :ErrorBacktrace => exn.backtrace.join('\r\n')
      })
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
      begin 
        yield
      rescue Exception => e
        log_exception(layer, e)
      ensure
        log_exit(layer)
      end
    end

    def self.start_trace(layer, opts={})
      log_start(layer, nil, opts)
      begin
        result = yield
        xtrace = log_end(layer)
        [result, xtrace]
      rescue Exception => e
        log_exception(layer, e)
        class << e
          attr_accessor :xtrace
        end
        e.xtrace = log_end(layer)
        raise
      end
    end

    def self.valid_key?(k)
      not ['Label', 'Layer', 'Edge', 'Timestamp', 'Timestamp_u'].include? k.to_s
    end
  end
end
