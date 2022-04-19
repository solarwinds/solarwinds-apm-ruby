# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Constants from liboboe
SW_APM_TRACE_DISABLED   = 0
SW_APM_TRACE_ENABLED  = 1

SAMPLE_RATE_MASK   = 0b0000111111111111111111111111
SAMPLE_SOURCE_MASK = 0b1111000000000000000000000000

# w3c trace context related global constants
# see: https://www.w3.org/TR/trace-context/#tracestate-limits
SW_APM_TRACESTATE_ID = 'sw'.freeze
SW_APM_MAX_TRACESTATE_BYTES = 512
SW_APM_MAX_TRACESTATE_MEMBER_BYTES = 128

SW_APM_STR_LAYER = 'Layer'.freeze
SW_APM_STR_LABEL = 'Label'.freeze

##
# This module is the base module for SolarWindsAPM reporting.
#
module SolarWindsAPMBase
  extend SolarWindsAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded

  thread_local :sample_source
  thread_local :sample_rate
  thread_local :layer
  thread_local :layer_op

  # trace context is used to store incoming w3c trace information
  thread_local :trace_context

  # transaction_name is used for custom transaction naming
  # It needs to be globally accessible, but is only set by the request processors of the different frameworks
  # and read by rack
  thread_local :transaction_name

  # Semaphore used during the test suite to test
  # global config options.
  thread_local :config_lock

  ##
  # tracing_layer?
  #
  # Queries the thread local variable about the current
  # layer being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  def tracing_layer?(layer)
    SolarWindsAPM.layer == layer.to_sym
  end

  ##
  # tracing_layer_op?
  #
  # Queries the thread local variable about the current
  # operation being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  # In such cases, we only want to trace the outermost operation.
  #
  def tracing_layer_op?(operation)
    unless SolarWindsAPM.layer_op.nil? || SolarWindsAPM.layer_op.is_a?(Array)
      SolarWindsAPM.logger.error('[SolarWindsAPM/logging] INTERNAL: layer_op should be nil or an array, please report to technicalsupport@solarwinds.com')
      return false
    end

    return false if SolarWindsAPM.layer_op.nil? || SolarWindsAPM.layer_op.empty? || !operation.respond_to?(:to_sym)
    SolarWindsAPM.layer_op.last == operation.to_sym
  end

  # TODO review use of these boolean statements
  # ____ they should now be handled by TransactionSettings,
  # ____ because there can be exceptions to :enabled and :disabled

  ##
  # Returns true if the tracing_mode is set to :enabled.
  # False otherwise
  #
  def tracing_enabled?
    SolarWindsAPM::Config[:tracing_mode] &&
      [:enabled, :always].include?(SolarWindsAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if the tracing_mode is set to :disabled.
  # False otherwise
  #
  def tracing_disabled?
    SolarWindsAPM::Config[:tracing_mode] &&
      [:disabled, :never].include?(SolarWindsAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    return false if !SolarWindsAPM.loaded # || SolarWindsAPM.tracing_disabled?
    SolarWindsAPM::Context.isSampled
  end

  def heroku?
    ENV.key?('SW_APM_URL')
  end

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    if (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ||
       (defined?(::Puma) && ($PROGRAM_NAME =~ /puma/i))
      true
    else
      false
    end
  end

  ##
  # Indicates whether a supported framework is in use
  # or not
  #
  def framework?
    defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
  end

  ##
  # These methods should be implemented by the descendants
  # currently only Oboe_metal
  #
  def sample?(_opts = {})
    fail 'sample? should be implemented by metal layer.'
  end

  def log(_layer, _label, _options = {})
    fail 'log should be implemented by metal layer.'
  end

  def set_tracing_mode(_mode)
    fail 'set_tracing_mode should be implemented by metal layer.'
  end

  def set_sample_rate(_rate)
    fail 'set_sample_rate should be implemented by metal layer.'
  end
end

module SolarWindsAPM
  extend SolarWindsAPMBase
end

# Setup an alias so we don't bug users
# about single letter capitalization
SolarwindsAPM = SolarWindsAPM
SolarWindsApm = SolarWindsAPM
SolarwindsApm = SolarWindsAPM
