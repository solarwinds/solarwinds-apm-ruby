# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe_metal
  class Event
    def self.metadataString(evt)
      evt.metadataString()
    end
  end

  class Context
    def self.log(layer, label, options = {}, with_backtrace = true)
      evt = Oboe::Context.createEvent()
      evt.addInfo("Layer", layer.to_s)
      evt.addInfo("Label", label.to_s)

      options.each_pair do |k, v|
        evt.addInfo(k.to_s, v.to_s)
      end

      evt.addInfo("Backtrace", Oboe::API.backtrace) if with_backtrace

      Oboe::Reporter.sendReport(evt)
    end

    def self.layer_op=(op)
      @layer_op = op
    end

    def self.layer_op
      @layer_op
    end

    def self.tracing_layer_op?(operation)
      if operation.is_a?(Array)
        return operation.include?(@layer_op)
      else
        return @layer_op == operation
      end
    end
  end
  
  module Reporter
    def self.sendReport(evt)
      Oboe.reporter.sendReport(evt)
    end
  end
end

module Oboe
  include Oboe_metal

  def self.reporter
    if !@reporter
      @reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
    end
    return @reporter
  end
end

Oboe_metal::Context.init() 

