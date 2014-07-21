# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'base'

module Oboe_metal
  include_package 'com.tracelytics.joboe'
  java_import 'com.tracelytics.joboe.LayerUtil'
  java_import 'com.tracelytics.joboe.SettingsReader'
  java_import 'com.tracelytics.joboe.Context'
  java_import 'com.tracelytics.joboe.Event'

  class Context
    class << self
      def toString
        md = getMetadata.toString
      end

      def clear
        clearMetadata
      end

      def get
        getMetadata
      end
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
        return unless Oboe.loaded

        if ENV['RACK_ENV'] == "test"
          Oboe.reporter = Java::ComTracelyticsJoboe::TestReporter.new
        else
          Oboe.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance().buildUdpReporter()
        end


        # Import the tracing mode and sample rate settings
        # from the Java agent (user configured in
        # /usr/local/tracelytics/javaagent.json when under JRuby)
        cfg = LayerUtil.getLocalSampleRate(nil, nil)

        if cfg.hasSampleStartFlag
          Oboe::Config.tracing_mode = 'always'
        elsif cfg.hasSampleThroughFlag
          Oboe::Config.tracing_mode = 'through'
        else
          Oboe::Config.tracing_mode = 'never'
        end

        Oboe::Config.sample_rate = cfg.sampleRate


        # Only report __Init from here if we are not instrumenting a framework.
        # Otherwise, frameworks will handle reporting __Init after full initialization
        unless defined?(::Rails) or defined?(::Sinatra) or defined?(::Padrino) or defined?(::Grape)
          Oboe::API.report_init
        end

      rescue Exception => e
        $stderr.puts e.message
        raise
      end
    end

    ##
    # clear_all_traces
    #
    # Truncates the trace output file to zero
    #
    def clear_all_traces
      Oboe.reporter.reset
    end

    ##
    # get_all_traces
    #
    # Retrieves all traces written to the trace file
    #
    def get_all_traces
      Oboe.reporter.getSentEventsAsBsonDocument
    end

    def self.sendReport(evt)
      evt.report(Oboe.reporter)
    end
  end
end

module Oboe
  extend OboeBase
  include Oboe_metal

  class << self
    def sample?(opts = {})
      return false unless Oboe.always?

      # Assure defaults since SWIG enforces Strings
      opts[:layer]      ||= ''
      opts[:xtrace]     ||= ''
      opts['X-TV-Meta']   ||= ''

      Java::ComTracelyticsJoboe::LayerUtil.shouldTraceRequest( opts[:layer],
                                                               { 'X-Trace'   => opts[:xtrace],
                                                                 'X-TV-Meta' => opts['X-TV-Meta'] } )
    end

    def set_tracing_mode(mode)
      Oboe.logger.warn "When using JRuby set the tracing mode in /usr/local/tracelytics/javaagent.json instead"
    end

    def set_sample_rate(rate)
      # N/A
    end
  end
end

Oboe.loaded = true

