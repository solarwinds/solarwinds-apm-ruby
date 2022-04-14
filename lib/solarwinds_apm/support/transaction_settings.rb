# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.
#

AO_TRACING_ENABLED = 1
AO_TRACING_DISABLED = 0
AO_TRACING_UNSET = -1

AO_TRACING_DECISIONS_OK = 0

OBOE_SETTINGS_UNSET = -1

module SolarWindsAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  class TransactionSettings

    attr_accessor :do_sample, :do_metrics
    attr_reader   :auth_msg, :do_propagate, :status_msg, :type, :source, :rate, :tracestring, :sw_member_value

    def initialize(url = '', headers = {}, options = nil)
      @do_metrics = false
      @do_sample = false
      @do_propagate = true

      SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)
      @tracestring = SolarWindsAPM.trace_context.tracestring
      @sw_member_value = SolarWindsAPM.trace_context.sw_member_value
      tracing_mode = AO_TRACING_ENABLED

      # TODO
      #   NH-11132 will address this
      # incoming tracing info has priority over existing context
      if SolarWindsAPM::Context.isValid && !@sw_member_value
        @do_sample = SolarWindsAPM.tracing?
        return
      end

      if url && asset?(url)
        @do_propagate = false
        return
      end

      if tracing_mode_disabled? && !tracing_enabled?(url) ||
        tracing_disabled?(url)

        tracing_mode = AO_TRACING_DISABLED
      end

      args = [@tracestring, @sw_member_value]
      args << tracing_mode
      args << (SolarWindsAPM::Config[:sample_rate] || OBOE_SETTINGS_UNSET)

      if options && (options.options || options.signature)
        args << (options.trigger_trace ? 1 : 0)
        args << (trigger_tracing_mode_disabled? ? 0 : 1)
        args << options.options
        args << options.signature
        args << options.timestamp
      end

      metrics, sample, @rate, @source, @bucket_rate, @bucket_cap, @type, @auth, @status_msg, @auth_msg, @status =
        SolarWindsAPM::Context.getDecisions(*args)

      if @status > AO_TRACING_DECISIONS_OK
        SolarWindsAPM.logger.warn "[solarwinds_apm/sample] Problem getting the sampling decisions: #{@status_msg} code: #{@status}"
      end

      @do_metrics = metrics > 0
      @do_sample = sample > 0
    end

    def to_s
      "do_propagate: #{do_propagate}, do_sample: #{do_sample}, do_metrics: #{do_metrics} rate: #{rate}, source: #{source}"
    end

    def add_kvs(kvs)
      kvs[:SampleRate] = @rate
      kvs[:SampleSource] = @source
    end

    def triggered_trace?
      @type == 1
    end

    def auth_ok?
      # @auth is undefined if initialize is called with an existing context
      !@auth || @auth < 1
    end

    private

    ##
    # check the config setting for :tracing_mode
    def tracing_mode_disabled?
      SolarWindsAPM::Config[:tracing_mode] &&
        [:disabled, :never].include?(SolarWindsAPM::Config[:tracing_mode])
    end

    ##
    # tracing_enabled?
    #
    # Given a path, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_enabled?(url)
      return false unless SolarWindsAPM::Config[:url_enabled_regexps].is_a? Array
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return SolarWindsAPM::Config[:url_enabled_regexps].any? { |regex| regex =~ url }
    rescue => e
      SolarWindsAPM.logger.warn "[SolarWindsAPM/filter] Could not apply :enabled filter to path. #{e.inspect}"
      true
    end

    ##
    # tracing_disabled?
    #
    # Given a path, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_disabled?(url)
      return false unless SolarWindsAPM::Config[:url_disabled_regexps].is_a? Array
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return SolarWindsAPM::Config[:url_disabled_regexps].any? { |regex| regex =~ url }
    rescue => e
      SolarWindsAPM.logger.warn "[SolarWindsAPM/filter] Could not apply :disabled filter to path. #{e.inspect}"
      false
    end

    def trigger_tracing_mode_disabled?
      SolarWindsAPM::Config[:trigger_tracing_mode] &&
        SolarWindsAPM::Config[:trigger_tracing_mode] == :disabled
    end

    ##
    # asset?
    #
    # Given a path, this method determines whether it is a static asset
    #
    def asset?(path)
      return false unless SolarWindsAPM::Config[:dnt_compiled]
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return SolarWindsAPM::Config[:dnt_compiled] =~ path
    rescue => e
      SolarWindsAPM.logger.warn "[SolarWindsAPM/filter] Could not apply do-not-trace filter to path. #{e.inspect}"
      false
    end

    public

    class << self

      def asset?(path)
        return false unless SolarWindsAPM::Config[:dnt_compiled]
        # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
        return SolarWindsAPM::Config[:dnt_compiled] =~ path
      rescue => e
        SolarWindsAPM.logger.warn "[SolarWindsAPM/filter] Could not apply do-not-trace filter to path. #{e.inspect}"
        false
      end

      def compile_url_settings(settings)
        if !settings.is_a?(Array) || settings.empty?
          reset_url_regexps
          return
        end

        # `tracing: disabled` is the default
        disabled = settings.select { |v| !v.has_key?(:tracing) || v[:tracing] == :disabled }
        enabled = settings.select { |v| v[:tracing] == :enabled }

        SolarWindsAPM::Config[:url_enabled_regexps] = compile_regexp(enabled)
        SolarWindsAPM::Config[:url_disabled_regexps] = compile_regexp(disabled)
      end

      def compile_regexp(settings)
        regexp_regexp     = compile_url_settings_regexp(settings)
        extensions_regexp = compile_url_settings_extensions(settings)

        regexps = [regexp_regexp, extensions_regexp].flatten.compact

        regexps.empty? ? nil : regexps
      end

      def compile_url_settings_regexp(value)
        regexps = value.select do |v|
          v.key?(:regexp) &&
            !(v[:regexp].is_a?(String) && v[:regexp].empty?) &&
            !(v[:regexp].is_a?(Regexp) && v[:regexp].inspect == '//')
        end

        regexps.map! do |v|
          begin
            v[:regexp].is_a?(String) ? Regexp.new(v[:regexp], v[:opts]) : Regexp.new(v[:regexp])
          rescue
            SolarWindsAPM.logger.warn "[solarwinds_apm/config] Problem compiling transaction_settings item #{v}, will ignore."
            nil
          end
        end
        regexps.keep_if { |v| !v.nil? }
        regexps.empty? ? nil : regexps
      end

      def compile_url_settings_extensions(value)
        extensions = value.select do |v|
          v.key?(:extensions) &&
            v[:extensions].is_a?(Array) &&
            !v[:extensions].empty?
        end
        extensions = extensions.map { |v| v[:extensions] }.flatten
        extensions.keep_if { |v| v.is_a?(String) }

        extensions.empty? ? nil : Regexp.new("(#{Regexp.union(extensions).source})(\\?.+){0,1}$")
      end

      def reset_url_regexps
        SolarWindsAPM::Config[:url_enabled_regexps] = nil
        SolarWindsAPM::Config[:url_disabled_regexps] = nil
      end
    end
  end
end
