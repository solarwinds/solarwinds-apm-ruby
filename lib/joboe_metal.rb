# Copyright (c) 2013 AppNeta, Inc.
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
      return unless Oboe.loaded

      if ENV.key?('OBOE_GEM_TEST')
        Oboe.reporter = Java::ComTracelyticsJoboe::TestReporter.new
      else
        Oboe.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance.buildUdpReporter
      end


      begin
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

        Oboe.sample_rate = cfg.getSampleRate
        Oboe::Config.sample_rate = cfg.sampleRate
        Oboe::Config.sample_source = cfg.sampleRateSourceValue
      rescue => e
        Oboe.logger.debug "[oboe/debug] Couldn't retrieve/acces joboe sampleRateCfg"
        Oboe.logger.debug "[oboe/debug] #{e.message}"
      end

      # Only report __Init from here if we are not instrumenting a framework.
      # Otherwise, frameworks will handle reporting __Init after full initialization
      unless defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
        Oboe::API.report_init unless ENV.key?('OBOE_GEM_TEST')
      end
    end

    ##
    # clear_all_traces
    #
    # Truncates the trace output file to zero
    #
    def self.clear_all_traces
      Oboe.reporter.reset if Oboe.loaded
    end

    ##
    # get_all_traces
    #
    # Retrieves all traces written to the trace file
    #
    def self.get_all_traces
      return [] unless Oboe.loaded

      # Joboe TestReporter returns a Java::ComTracelyticsExtEbson::DefaultDocument
      # document for traces which doesn't correctly support things like has_key? which
      # raises an unhandled exception on non-existent key (duh).  Here we convert
      # the Java::ComTracelyticsExtEbson::DefaultDocument doc to a pure array of Ruby
      # hashes
      traces = []
      Oboe.reporter.getSentEventsAsBsonDocument.to_a.each do |e|
        t = {}
        e.each_pair { |k, v|
          t[k] = v
        }
        traces << t
      end
      traces
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
      begin
        return false unless Oboe.always? && Oboe.loaded

        return true if ENV.key?('OBOE_GEM_TEST')

        # Validation to make Joboe happy.  Assure that we have the KVs and that they
        # are not empty strings.
        opts[:layer]  = nil      if opts[:layer].is_a?(String)      && opts[:layer].empty?
        opts[:xtrace] = nil      if opts[:xtrace].is_a?(String)     && opts[:xtrace].empty?
        opts['X-TV-Meta'] = nil  if opts['X-TV-Meta'].is_a?(String) && opts['X-TV-Meta'].empty?

        opts[:layer]      ||= nil
        opts[:xtrace]     ||= nil
        opts['X-TV-Meta'] ||= nil

        sr_cfg = Java::ComTracelyticsJoboe::LayerUtil.shouldTraceRequest(
                                              opts[:layer],
                                              { 'X-Trace' => opts[:xtrace], 'X-TV-Meta' => opts['X-TV-Meta'] })

        # Store the returned SampleRateConfig into Oboe::Config
        if sr_cfg
          begin
            Oboe.sample_rate = sr_cfg.sampleRate
            Oboe.sample_source = sr_cfg.sampleRateSource.a
            # If we fail here, we do so quietly.  This was we don't spam logs
            # on every request
          end
        else
          Oboe.sample_rate = -1
          Oboe.sample_source = -1
        end

        sr_cfg
      rescue => e
        Oboe.logger.debug "[oboe/debug] #{e.message}"
        false
      end
    end

    def set_tracing_mode(_mode)
      Oboe.logger.warn 'When using JRuby set the tracing mode in /usr/local/tracelytics/javaagent.json instead'
    end

    def set_sample_rate(_rate)
      # N/A
    end
  end
end

# Assure that the Joboe Java Agent was loaded via premain
case Java::ComTracelyticsAgent::Agent.getStatus
  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_SUCCESSFUL
    Oboe.loaded = true

  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_FAILED
    Oboe.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'TraceView Java Agent not initialized properly.'
    $stderr.puts 'Possibly misconfigured?  Going into no-op mode.'
    $stderr.puts 'See: http://bit.ly/1zwS5xj'
    $stderr.puts '=============================================================='

  when Java::ComTracelyticsAgent::Agent::AgentStatus::UNINITIALIZED
    Oboe.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'TraceView Java Agent not loaded. Going into no-op mode.'
    $stderr.puts 'To preload the TraceView java agent see:'
    $stderr.puts 'https://support.appneta.com/cloud/installing-jruby-instrumentation'
    $stderr.puts '=============================================================='

  else
    Oboe.loaded = false
end
