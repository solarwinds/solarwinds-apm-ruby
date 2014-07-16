# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'base'

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

        Oboe_metal::Context.init()

        if ENV['RACK_ENV'] == "test"
          Oboe.reporter = Oboe::FileReporter.new("/tmp/trace_output.bson")
        else
          Oboe.reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
        end

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

    def self.sendReport(evt)
      evt.report
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
      Java::ComTracelyticsJoboeSettingsReader.shouldTraceRequest(opts[:layer], opts[:xtrace], opts['X-TV-Meta'])
    end

    def set_tracing_mode(mode)
      # FIXME: TBD
    end

    def set_sample_rate(rate)
      # FIXME: TBD
    end
  end
end

Oboe.loaded = true
