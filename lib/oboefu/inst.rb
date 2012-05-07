# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    def self.trace_start_layer_block(layer, header, opts={})
      Oboe::Context.clear()

      if header and Oboe.passthrough?
        Oboe::Context.fromString(header)
      end

      if not (Oboe.start? or Oboe.tracing?)
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

    def self.layer_sentinel(layer, opts={})
      if Oboe.start?
        Oboe::API.log_start(layer, opts)
      elsif Oboe.continue?
        Oboe::API.log_entry(layer, opts)
      else
        return nil
      end

      exitEvent = Oboe::Context.createEvent
      exitEvent.addInfo('Layer', layer)
      exitEvent.addInfo('Label', 'exit')
      exitEvent.addEdge(Oboe::Context.get())

      exitEvent
    end
  end
end
