# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.
#

AO_TRACING_ENABLED = 1
AO_TRACING_DISABLED = 0
AO_TRACING_UNSET = -1

AO_TRACING_DECISIONS_TRACING_DISABLED = -2
AO_TRACING_DECISIONS_XTRACE_NOT_SAMPLED = -1
AO_TRACING_DECISIONS_OK = 0
AO_TRACING_DECISIONS_NULL_OUT = 1
AO_TRACING_DECISIONS_NO_CONFIG = 2
AO_TRACING_DECISIONS_REPORTER_NOT_READY = 3
AO_TRACING_DECISIONS_NO_VALID_SETTINGS = 4
AO_TRACING_DECISIONS_QUEUE_FULL = 5

module AppOpticsAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  class TransactionSettings

    attr_accessor :do_metrics, :do_sample
    attr_reader   :do_propagate, :rate, :source

    def initialize(url = nil, xtrace = '')
      @do_metrics = false
      @do_sample = false
      @do_propagate = true
      tracing_mode = AO_TRACING_ENABLED

      if AppOpticsAPM::Context.isValid
        @do_sample = AppOpticsAPM.tracing?
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

      args = [xtrace || '']
      args << tracing_mode
      args << AppOpticsAPM::Config[:sample_rate] if AppOpticsAPM::Config[:sample_rate]&. >= 0

      metrics, sample, @rate, @source, return_code = AppOpticsAPM::Context.getDecisions(*args)

      puts "return_code class: #{return_code.class}" unless return_code.is_a? Integer
      if return_code > AO_TRACING_DECISIONS_OK
        AppOpticsAPM.logger.warn "[appoptics-apm/sample] Problem getting the sampling decisions, code: #{return_code}"
      end

      @do_metrics = metrics > 0
      @do_sample = sample > 0
    end

    def to_s
      "do_propagate: #{do_propagate}, do_sample: #{do_sample}, do_metrics: #{do_metrics} rate: #{rate}, source: #{source}"
    end

    private

    ##
    # check the config setting for :tracing_mode
    def tracing_mode_disabled?
      AppOpticsAPM::Config[:tracing_mode] &&
        [:disabled, :never].include?(AppOpticsAPM::Config[:tracing_mode])
    end

    ##
    # tracing_enabled?
    #
    # Given a path, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_enabled?(url)
      return false unless AppOpticsAPM::Config[:url_enabled_regexps].is_a? Array
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return AppOpticsAPM::Config[:url_enabled_regexps].any? { |regex| regex =~ url }
    rescue => e
      AppOpticsAPM.logger.warn "[AppOpticsAPM/filter] Could not apply :enabled filter to path. #{e.inspect}"
      true
    end

    ##
    # tracing_disabled?
    #
    # Given a path, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_disabled?(url)
      return false unless AppOpticsAPM::Config[:url_disabled_regexps].is_a? Array
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return AppOpticsAPM::Config[:url_disabled_regexps].any? { |regex| regex =~ url }
    rescue => e
      AppOpticsAPM.logger.warn "[AppOpticsAPM/filter] Could not apply :disabled filter to path. #{e.inspect}"
      false
    end

    ##
    # asset?
    #
    # Given a path, this method determines whether it is a static asset
    #
    def asset?(path)
      return false unless AppOpticsAPM::Config[:dnt_compiled]
      # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
      return AppOpticsAPM::Config[:dnt_compiled] =~ path
    rescue => e
      AppOpticsAPM.logger.warn "[AppOpticsAPM/filter] Could not apply do-not-trace filter to path. #{e.inspect}"
      false
    end

    public

    class << self

      def asset?(path)
        return false unless AppOpticsAPM::Config[:dnt_compiled]
        # once we only support Ruby >= 2.4.0 use `match?` instead of `=~`
        return AppOpticsAPM::Config[:dnt_compiled] =~ path
      rescue => e
        AppOpticsAPM.logger.warn "[AppOpticsAPM/filter] Could not apply do-not-trace filter to path. #{e.inspect}"
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

        AppOpticsAPM::Config[:url_enabled_regexps] = compile_regexp(enabled)
        AppOpticsAPM::Config[:url_disabled_regexps] = compile_regexp(disabled)
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
            AppOpticsAPM.logger.warn "[appoptics_apm/config] Problem compiling transaction_settings item #{v}, will ignore."
            nil
          end
        end
        regexps.keep_if { |v| !v.nil?}
        regexps.empty? ? nil : regexps
      end

      def compile_url_settings_extensions(value)
        extensions = value.select do |v|
          v.key?(:extensions) &&
            v[:extensions].is_a?(Array) &&
            !v[:extensions].empty?
        end
        extensions = extensions.map { |v| v[:extensions] }.flatten
        extensions.keep_if { |v| v.is_a?(String)}

        extensions.empty? ? nil : Regexp.new("(#{Regexp.union(extensions).source})(\\?.+){0,1}$")
      end

      def reset_url_regexps
        AppOpticsAPM::Config[:url_enabled_regexps] = nil
        AppOpticsAPM::Config[:url_disabled_regexps] = nil
      end
    end
  end
end
