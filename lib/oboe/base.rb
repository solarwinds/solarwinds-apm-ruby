# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

# Constants from liboboe
OBOE_TRACE_NEVER   = 0
OBOE_TRACE_ALWAYS  = 1
OBOE_TRACE_THROUGH = 2

OBOE_SAMPLE_RATE_SOURCE_FILE                   = 1
OBOE_SAMPLE_RATE_SOURCE_DEFAULT                = 2
OBOE_SAMPLE_RATE_SOURCE_OBOE                   = 3
OBOE_SAMPLE_RATE_SOURCE_LAST_OBOE              = 4
OBOE_SAMPLE_RATE_SOURCE_DEFAULT_MISCONFIGURED  = 5
OBOE_SAMPLE_RATE_SOURCE_OBOE_DEFAULT           = 6

# Masks for bitwise ops
ZERO_MASK = 0b0000000000000000000000000000

SAMPLE_RATE_MASK   = 0b0000111111111111111111111111
SAMPLE_SOURCE_MASK = 0b1111000000000000000000000000

ZERO_SAMPLE_RATE_MASK   = 0b1111000000000000000000000000
ZERO_SAMPLE_SOURCE_MASK = 0b0000111111111111111111111111

##
# This module is the base module for the various implementations of Oboe reporting.
# Current variations as of 2014-09-10 are a c-extension, JRuby (using TraceView Java
# instrumentation) and a Heroku c-extension (with embedded tracelyzer)
module OboeBase
  extend ::Oboe::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded
  attr_accessor :sample_source
  attr_accessor :sample_rate
  thread_local :layer_op

  def self.included(_)
    self.loaded = true
  end

  def tracing_layer_op?(operation)
    if operation.is_a?(Array)
      return operation.include?(Oboe.layer_op)
    else
      return Oboe.layer_op == operation
    end
  end

  ##
  # Returns true if the tracing_mode is set to always.
  # False otherwise
  #
  def always?
    Oboe::Config[:tracing_mode].to_s == 'always'
  end

  ##
  # Returns true if the tracing_mode is set to never.
  # False otherwise
  #
  def never?
    Oboe::Config[:tracing_mode].to_s == 'never'
  end

  ##
  # Returns true if the tracing_mode is set to always or through.
  # False otherwise
  #
  def passthrough?
    %w(always through).include?(Oboe::Config[:tracing_mode])
  end

  ##
  # Returns true if the tracing_mode is set to through.
  # False otherwise
  #
  def through?
    Oboe::Config[:tracing_mode] == 'through'
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    return false unless Oboe.loaded

    Oboe::Context.isValid && !Oboe.never?
  end

  def log(layer, label, options = {})
    # WARN: Oboe.log will be deprecated in a future release.  Please use Oboe::API.log instead.
    Oboe::API.log(layer, label, options)
  end

  def heroku?
    ENV.key?('TRACEVIEW_URL')
  end

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ? true : false
  end

  ##
  # Indicates whether a supported framework is in use
  # or not
  #
  def framework?
    defined?(::Rails) or defined?(::Sinatra) or defined?(::Padrino) or defined?(::Grape)
  end

  ##
  # These methods should be implemented by the descendants
  # (Oboe_metal, Oboe_metal (JRuby), Heroku_metal)
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

module Oboe
  extend OboeBase
end
