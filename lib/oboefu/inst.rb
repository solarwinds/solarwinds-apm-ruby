# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

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
    def self.trace_start_layer_block(layer, header, opts={})
      Oboe::Context.clear()

      if header and Oboe.passthrough?
        Oboe::Context.fromString(header)
      end

      if not (Oboe.start? or Oboe.continue?)
        return [yield(nil), header]
      end

      exitEvent = Oboe::Inst.layer_sentinel(layer, opts)

      begin
        result = yield(exitEvent)
        [result, exitEvent.metadataString()]
      rescue => e
        Oboe::Inst.log_exception(layer, e)
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

    def self.trace_layer_block_without_exception(layer, opts)
      Oboe::Context.log(layer, 'entry', opts)

      begin
        result = yield
      ensure
        Oboe::Inst.log(layer, 'exit')
      end

      return result
    end

    def self.trace_layer_block_ss(layer, obj, method, *args)
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
        obj.send("clean_#{method}", *args)
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

    def self.layer_sentinel(layer, opts={})
      if Oboe.start?
        entryEvent = Oboe::Context.startTrace
      elsif Oboe.continue?
        entryEvent = Oboe::Context.createEvent
      else
        return nil
      end

      entryEvent.addInfo('Layer', layer)
      entryEvent.addInfo('Label', 'entry')
      opts.each do |k, v|
        entryEvent.addInfo(k.to_s.capitalize, v.to_s)
      end if opts and opts.size
      Oboe.reporter.sendReport(entryEvent)

      exitEvent = Oboe::Context.createEvent
      exitEvent.addInfo('Layer', layer)
      exitEvent.addInfo('Label', 'exit')
      exitEvent.addEdge(Oboe::Context.get())

      exitEvent
    end
  end
end
