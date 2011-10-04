module Oboe
  module Inst
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
  end
end
