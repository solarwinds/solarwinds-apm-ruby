# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe_metal
  include_package 'com.tracelytics.joboe'
  import 'com.tracelytics.joboe'
  include_package 'com.tracelytics.joboe.SettingsReader'
  import 'com.tracelytics.joboe.SettingsReader'
  include_package 'com.tracelytics.joboe.Context'
  import 'com.tracelytics.joboe.Context'
  include_package 'com.tracelytics.joboe.Event'
  import 'com.tracelytics.joboe.Event'

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

    def self.toString
      md = getMetadata.toString
    end

    def self.clear
      clearMetadata
    end

    def self.get
      getMetadata
    end
  end
  
  class Event
    def self.metadataString(evt)
      evt.getMetadata.toHexString
    end
  end

  def UdpReporter
    Java::ComTracelyticsJoboe
  end
  
  module Metadata
    Java::ComTracelyticsJoboeMetaData
  end
  
  module Reporter
    def self.sendReport(evt)
      evt.report
    end
  end
end

module Oboe
  include Oboe_metal
  
  def self.always?
    Oboe::Config[:tracing_mode].to_s == "always"
  end
  
  def self.log(layer, label, options = {})
    Context.log(layer, label, options = options)
  end
  
  def self.never?
    Oboe::Config[:tracing_mode].to_s == "never"
  end

  def self.passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end
    
  def self.sample?
    Java::ComTracelyticsJoboeSettingsReader.shouldTraceRequest('', '')
  end

  def self.through?
    Oboe::Config[:tracing_mode] == "through"
  end
    
  def self.tracing?
    Oboe::Context.isValid and not Oboe.never?
  end

  def self.reporter
    if !@reporter
      @reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
    end
    return @reporter
  end
end
