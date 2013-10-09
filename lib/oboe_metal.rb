# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe_metal
  class Event
    def self.metadataString(evt)
      evt.metadataString()
    end
  end

  class Context
    class << self
      attr_accessor :layer_op

      def log(layer, label, options = {}, with_backtrace = false)
        evt = Oboe::Context.createEvent()
        evt.addInfo("Layer", layer.to_s)
        evt.addInfo("Label", label.to_s)

        options.each_pair do |k, v|
          evt.addInfo(k.to_s, v.to_s)
        end

        evt.addInfo("Backtrace", Oboe::API.backtrace) if with_backtrace

        Oboe.reporter.sendReport(evt)
      end

      def tracing_layer_op?(operation)
        if operation.is_a?(Array)
          return operation.include?(@layer_op)
        else
          return @layer_op == operation
        end
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
      Oboe::Context.sampleRequest(opts[:layer], opts[:xtrace], opts['X-TV-Meta'])
    end

    def through?
      Oboe::Config[:tracing_mode] == "through"
    end
      
    def tracing?
      Oboe::Context.isValid and not Oboe.never?
    end
  end
end

begin
  Oboe_metal::Context.init() 
  Oboe.reporter = Oboe::UdpReporter.new("127.0.0.1")

rescue Exception => e
  $stderr.puts e.message
  raise
end

