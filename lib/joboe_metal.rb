# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module Oboe_metal
  include_package 'com.tracelytics.joboe'
  java_import 'com.tracelytics.joboe.LayerUtil'
  java_import 'com.tracelytics.joboe.SettingsReader'
  java_import 'com.tracelytics.joboe.Context'
  java_import 'com.tracelytics.joboe.Event'
  java_import 'com.tracelytics.agent.Agent'

  class Context
    class << self
      def toString
        getMetadata.toHexString
      end

      def fromString(xtrace)
        Context.setMetadata(xtrace)
      end

      def clear
        clearMetadata
      end

      def get
        getMetadata
      end
    end
  end

  module EventUtil
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
    class << self
      ##
      # start
      #
      # Start the SolarWindsAPM Reporter
      #
      def start
        return unless SolarWindsAPM.loaded

        if ENV.key?('SW_AMP_GEM_TEST')
          SolarWindsAPM.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance.buildTestReporter(false)
        else
          SolarWindsAPM.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance.buildUdpReporter
        end

        begin
          # Import the tracing mode and sample rate settings
          # from the Java agent (user configured in
          # /usr/local/tracelytics/javaagent.json when under JRuby)
          cfg = LayerUtil.getLocalSampleRate(nil, nil)

          if cfg.hasSampleStartFlag
            SolarWindsAPM::Config.tracing_mode = :enabled
          else
            SolarWindsAPM::Config.tracing_mode = :disabled
          end

          SolarWindsAPM.sample_rate = cfg.getSampleRate
          SolarWindsAPM::Config.sample_rate = cfg.sampleRate
          SolarWindsAPM::Config.sample_source = cfg.sampleRateSourceValue
        rescue => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] Couldn't retrieve/acces joboe sampleRateCfg"
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{e.message}"
        end

        # Only report __Init from here if we are not instrumenting a framework.
        # Otherwise, frameworks will handle reporting __Init after full initialization
        unless defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
          SolarWindsAPM::API.report_init unless ENV.key?('SW_AMP_GEM_TEST')
        end
      end

      ##
      # restart
      #
      # This is a nil method for SolarWindsAPM under Java.  It is maintained only
      # for compability across interfaces.
      #
      def restart
        SolarWindsAPM.logger.warn "[solarwinds_apm/reporter] Reporter.restart isn't supported under JRuby"
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        SolarWindsAPM.reporter.reset if SolarWindsAPM.loaded
      end

      ##
      # get_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def get_all_traces
        return [] unless SolarWindsAPM.loaded

        # Joboe TestReporter returns a Java::ComTracelyticsExtEbson::DefaultDocument
        # document for traces which doesn't correctly support things like has_key? which
        # raises an unhandled exception on non-existent key (duh).  Here we convert
        # the Java::ComTracelyticsExtEbson::DefaultDocument doc to a pure array of Ruby
        # hashes
        traces = []
        SolarWindsAPM.reporter.getSentEventsAsBsonDocument.to_a.each do |e|
          t = {}
          e.each_pair { |k, v|
            t[k] = v
          }
          traces << t
        end
        traces
      end

      def sendReport(evt)
        evt.report(SolarWindsAPM.reporter)
      end
    end
  end
end

module SolarWindsAPM
  extend SolarWindsAPMBase
  include Oboe_metal

  class << self
    def sample?(opts = {})
      begin
        # Return false if no-op mode
        return false unless SolarWindsAPM.loaded

        return true if ENV.key?('SW_AMP_GEM_TEST')

        # Validation to make Joboe happy.  Assure that we have the KVs and that they
        # are not empty strings.
        opts[:xtrace] = nil      if opts[:xtrace].is_a?(String)     && opts[:xtrace].empty?

        opts[:xtrace]     ||= nil

        sr_cfg = Java::ComTracelyticsJoboe::LayerUtil.shouldTraceRequest(SW_AMP_STR_BLANK, { 'X-Trace' => opts[:xtrace] })

        # Store the returned SampleRateConfig into SolarWindsAPM::Config
        if sr_cfg
          begin
            SolarWindsAPM::Config.sample_rate = sr_cfg.sampleRate
            SolarWindsAPM::Config.sample_source = sr_cfg.sampleRateSourceValue
            # If we fail here, we do so quietly.  This was we don't spam logs
            # on every request
          end
        else
          SolarWindsAPM.sample_rate = -1
          SolarWindsAPM.sample_source = -1
        end

        sr_cfg ? true : false
      rescue => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{e.message}"
        false
      end
    end

    def set_tracing_mode(_mode)
      SolarWindsAPM.logger.warn '[solarwinds_apm/joboe] When using JRuby set the tracing mode in /usr/local/tracelytics/javaagent.json instead'
    end

    def set_sample_rate(_rate)
      # N/A
    end
  end
end

# Assure that the Joboe Java Agent was loaded via premain
case Java::ComTracelyticsAgent::Agent.getStatus
  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_SUCCESSFUL
    SolarWindsAPM.loaded = true

  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_FAILED
    SolarWindsAPM.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'SolarWindsAPM Java Agent not initialized properly.'
    $stderr.puts 'Possibly misconfigured?  Going into no-op mode.'
    $stderr.puts 'http://docs.appoptics.solarwinds.com/Instrumentation/other-instrumentation-modules.html#jruby'
    $stderr.puts '=============================================================='

  when Java::ComTracelyticsAgent::Agent::AgentStatus::UNINITIALIZED
    SolarWindsAPM.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'SolarWindsAPM Java Agent not loaded. Going into no-op mode.'
    $stderr.puts 'To preload the SolarWindsAPM java agent see:'
    $stderr.puts 'http://docs.appoptics.solarwinds.com/Instrumentation/other-instrumentation-modules.html#jruby'
    $stderr.puts '=============================================================='

  else
    SolarWindsAPM.loaded = false
end
