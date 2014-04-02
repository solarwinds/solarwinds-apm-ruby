# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'base'

module Oboe_metal
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

  class Event
    def self.metadataString(evt)
      evt.metadataString()
    end
  end

  class Reporter
    ##
    # Initialize the Oboe Context, reporter and report the initialization
    #
    def self.start
      return unless Oboe.loaded

      begin
        Oboe_metal::Context.init() 

        if ENV['RACK_ENV'] == "test"
          Oboe.reporter = Oboe::FileReporter.new("/tmp/trace_output.bson")
        else
          Oboe.reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
        end

        # Only report __Init from here if we are not instrumenting a framework.
        # Otherwise, frameworks will handle reporting __Init after full initialization
        unless defined?(::Rails) or defined?(::Sinatra) or defined?(::Padrino)
          Oboe::API.report_init
        end

      rescue Exception => e
        $stderr.puts e.message
        raise
      end
    end

    def self.sendReport(evt)
      Oboe.reporter.sendReport(evt)
    end
  end
end

module Oboe 
  extend OboeBase
  include Oboe_metal

  class << self
    def sample?(opts = {})
      begin
        # Assure defaults since SWIG enforces Strings
        layer   = opts[:layer]      ? opts[:layer].strip      : ''
        xtrace  = opts[:xtrace]     ? opts[:xtrace].strip     : ''
        tv_meta = opts['X-TV-Meta'] ? opts['X-TV-Meta'].strip : ''

        rv = Oboe::Context.sampleRequest(layer, xtrace, tv_meta)

        # For older liboboe that returns true/false, just return that.
        return rv if [TrueClass, FalseClass].include?(rv.class) or (rv == 0)

        # liboboe version > 1.3.1 returning a bit masked integer with SampleRate and
        # source embedded
        Oboe.sample_rate = (rv & SAMPLE_RATE_MASK)
        Oboe.sample_source = (rv & SAMPLE_SOURCE_MASK) >> 24
      rescue StandardError => e
        Oboe.logger.debug "[oboe/error] sample? error: #{e.inspect}"
        false
      end
    end

    def set_tracing_mode(mode)
      return unless Oboe.loaded

      value = mode.to_sym

      case value
      when :never
        Oboe::Context.setTracingMode(OBOE_TRACE_NEVER)

      when :always
        Oboe::Context.setTracingMode(OBOE_TRACE_ALWAYS)

      when :through
        Oboe::Context.setTracingMode(OBOE_TRACE_THROUGH)

      else
        Oboe.logger.fatal "[oboe/error] Invalid tracing mode set: #{mode}"
        Oboe::Context.setTracingMode(OBOE_TRACE_THROUGH)
      end
    end

    def set_sample_rate(rate)
      if Oboe.loaded
        # Update liboboe with the new SampleRate value
        Oboe::Context.setDefaultSampleRate(rate.to_i)
      end
    end
  end
end

Oboe.loaded = true

