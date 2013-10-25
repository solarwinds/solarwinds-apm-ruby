# Copyright (c) 2013 AppNeta, Inc.
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
    def self.log(layer, label, options = {}, with_backtrace = false)
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
    ##
    # Initialize the Oboe Context, reporter and report the initialization
    #
    def self.start
      begin
        Oboe_metal::Context.init() 

        if ENV['RACK_ENV'] == "test"
          Oboe.reporter = Oboe::FileReporter.new("./tmp/trace_output.bson")
        else
          Oboe.reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
        end

        Oboe::API.report_init('rack') unless ["development", "test"].include? ENV['RACK_ENV']
      
      rescue Exception => e
        $stderr.puts e.message
        raise
      end
    end
    
    def self.sendReport(evt)
      evt.report
    end
  end
end

module Oboe
  include Oboe_metal
  
  class << self
    attr_accessor :reporter
  
    def always?
      Oboe::Config[:tracing_mode].to_s == "always"
    end
    
    def log(layer, label, options = {})
      Context.log(layer, label, options = options)
    end
    
    def never?
      Oboe::Config[:tracing_mode].to_s == "never"
    end

    def passthrough?
      ["always", "through"].include?(Oboe::Config[:tracing_mode])
    end
      
    def sample?(opts = {})
      # Assure defaults since SWIG enforces Strings
      opts[:layer]      ||= ''
      opts[:xtrace]     ||= ''
      opts['X-TV-Meta']   ||= ''
      Java::ComTracelyticsJoboeSettingsReader.shouldTraceRequest(opts[:layer], opts[:xtrace], opts['X-TV-Meta'])
    end

    def through?
      Oboe::Config[:tracing_mode] == "through"
    end
      
    def tracing?
      Oboe::Context.isValid and not Oboe.never?
    end
  end
end
