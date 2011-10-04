module Oboe
  module Inst
    def self.trace_start_layer_block(layer, header, opts={})
      Oboe::Context.clear()

      if header and Oboe.passthrough?
        Oboe::Context.fromString(header)
      end

      if not (Oboe.start? or Oboe.continue?)
        return [yield, header]
      end

      entryEvent, exitEvent = Oboe::Inst.layer_sentinels(layer)

      opts.each do |k, v|
        entryEvent.addInfo(k.to_s, v.to_s)
      end if opts and opts.size
      Oboe.reporter.sendReport(entryEvent)

      begin
        result = yield
        [result, exitEvent.metadataString()]
      rescue => e
        Oboe::Inst.log_exception(e)
      ensure
        exitEvent.addEdge(Oboe::Context.get())
        Oboe.reporter.sendReport(exitEvent)
        Oboe::Context.clear()
      end
    end

    def self.trace_layer_block(layer, opts) 
      Oboe::Context.log(layer, 'entry', opts)

      begin
        result = yield
      rescue Exception => e
        Oboe::Inst.log_exception(layer, e)
        raise
      ensure
        Oboe::Inst.log(layer, 'exit')
      end

      return result
    end

    def self.trace_layer_block_ss(layer, method, *args)
      opts = {}

      Oboe::Context.log(layer, 'entry')

      if Oboe.now?
        begin
          result, opts = yield(*args)
        rescue Exception => e
          Oboe::Inst.log_exception(layer, e)
          raise
        end

        result
      else
        send("clean_#{method}", *args)
      end

    ensure
      Oboe::Inst.log(layer, 'exit', opts)
    end

    def self.log(layer, label, opts = {})
      return unless Oboe.now?

      evt = Oboe::Context.createEvent
      evt.addInfo('Layer', layer)
      evt.addInfo('Label', label)

      opts.each do |k, v|
        evt.addInfo(k.to_s, v.to_s)
      end if opts and opts.size

      Oboe.reporter.sendReport(evt)
    end

    def self.log_exception(layer, exn)
      return unless Oboe.now?

      Oboe::Context.log(layer, 'error', {
          :ErrorClass => exn.class.name,
          :Message => exn.message,
          :ErrorBacktrace => exn.backtrace.join('\r\n')
      })
    end

    def self.layer_sentinels(layer)
      if Oboe.start?
        entryEvent = Oboe::Context.startTrace
      elsif Oboe.continue?
        entryEvent = Oboe::Context.createEvent
      else
        return [nil, nil]
      end

      entryEvent.addInfo('Layer', layer)
      entryEvent.addInfo('Label', 'entry')

      exitEvent = Oboe::Context.createEvent
      exitEvent.addInfo('Layer', layer)
      exitEvent.addInfo('Label', 'exit')
      exitEvent.addEdge(Oboe::Context.get())

      [entryEvent, exitEvent]
    end
  end
end
