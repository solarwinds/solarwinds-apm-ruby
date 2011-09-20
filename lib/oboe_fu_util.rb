module Oboe
  module Inst
    def self.trace_layer_block(layer, opts) 
      if Oboe.now?
        Oboe::Context.log(layer, 'entry', opts)
      end

      begin
        result = yield
      ensure
        if Oboe.now?
          evt = Oboe::Context.createEvent()
          evt.addInfo('Layer', layer)
          evt.addInfo('Label', 'exit')
          Oboe.reporter.sendReport(evt)
        end
      end

      return result
    end

    def self.log(layer, label, opts)
      if Oboe.now?
        evt = Oboe::Context.createEvent
        evt.addInfo('Layer', layer)
        evt.addInfo('Label', label)

        opts.each do |k, v|
          evt.addInfo(k.to_s, v.to_s)
        end

        Oboe.reporter.sendReport(evt)
      end
    end
  end
end
