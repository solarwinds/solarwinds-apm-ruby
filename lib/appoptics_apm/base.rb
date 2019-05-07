# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Constants from liboboe
APPOPTICS_TRACE_DISABLED   = 0
APPOPTICS_TRACE_ENABLED  = 1

# OBOE_SAMPLE_RATE_SOURCE_FILE                   = 1
# OBOE_SAMPLE_RATE_SOURCE_DEFAULT                = 2
# OBOE_SAMPLE_RATE_SOURCE_OBOE                   = 3
# OBOE_SAMPLE_RATE_SOURCE_LAST_OBOE              = 4
# OBOE_SAMPLE_RATE_SOURCE_DEFAULT_MISCONFIGURED  = 5
# OBOE_SAMPLE_RATE_SOURCE_OBOE_DEFAULT           = 6

# Masks for bitwise ops
# ZERO_MASK = 0b0000000000000000000000000000

SAMPLE_RATE_MASK   = 0b0000111111111111111111111111
SAMPLE_SOURCE_MASK = 0b1111000000000000000000000000

# ZERO_SAMPLE_RATE_MASK   = 0b1111000000000000000000000000
# ZERO_SAMPLE_SOURCE_MASK = 0b0000111111111111111111111111

# APPOPTICS_STR_BLANK = ''.freeze
APPOPTICS_STR_LAYER = 'Layer'.freeze
APPOPTICS_STR_LABEL = 'Label'.freeze

##
# This module is the base module for the various implementations of AppOpticsAPM reporting.
# Current variations as of 2014-09-10 are a c-extension, JRuby (using AppOpticsAPM Java
# instrumentation) and a Heroku c-extension (with embedded tracelyzer)
module AppOpticsAPMBase
  extend AppOpticsAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded
  thread_local :sample_source
  thread_local :sample_rate
  thread_local :layer
  thread_local :layer_op

  # transaction_name is used for custom transaction naming
  # It needs to be globally accessible, but is only set by the request processors of the different frameworks
  # and read by rack
  thread_local :transaction_name

  # Semaphore used during the test suite to test
  # global config options.
  thread_local :config_lock

  # The following accessors indicate the incoming tracing state received
  # by the rack layer.  These are primarily used to identify state
  # between the Ruby and JAppOpticsAPM instrumentation under JRuby.
  #
  # This is because that even though there may be an incoming
  # X-Trace request header, tracing may have already been started
  # by Joboe.  Such a scenario occurs when the application is being
  # hosted by a Java container (such as Tomcat or Glassfish) and
  # AppOpticsAPM has already initiated tracing.  In this case, we shouldn't
  # pickup the X-Trace context in the X-Trace header and we shouldn't
  # set the outgoing response X-Trace header or clear context.
  # Yeah I know.  Yuck.

  # Occurs only on Jruby.  Indicates that Joboe (the java instrumentation)
  # has already started tracing before it hit the JRuby instrumentation.
  # It is used in Rack#call if there is a context when entering rack
  thread_local :has_incoming_context

  # Indicates the existence of a valid X-Trace request header
  thread_local :has_xtrace_header

  # This indicates that this trace was continued from
  # an incoming X-Trace request header or in the case
  # of JRuby, a trace already started by JAppOpticsAPM.
  thread_local :is_continued_trace

  ##
  # extended
  #
  # Invoked when this module is extended.
  # e.g. extend AppOpticsAPMBase
  #
  def self.extended(cls)
    cls.loaded = true

    # This gives us pretty accessors with questions marks at the end
    # e.g. is_continued_trace --> is_continued_trace?
    AppOpticsAPM.methods.select { |m| m =~ /^is_|^has_/ }.each do |c|
      unless c =~ /\?$|=$/
        # AppOpticsAPM.logger.debug "aliasing #{c}? to #{c}"
        alias_method "#{c}?", c
      end
    end
  end

  ##
  # pickup_context
  #
  # for JRUBY
  # Determines whether we should pickup context
  # from an incoming X-Trace request header.  The answer
  # is generally yes but there are cases in JRuby under
  # Tomcat (or Glassfish etc.) where tracing may have
  # been already started by the Java instrumentation (Joboe)
  # in which case we don't want to do this.
  #
  def pickup_context?(xtrace)
    return false unless AppOpticsAPM::XTrace.valid?(xtrace)

    if defined?(JRUBY_VERSION) && AppOpticsAPM.tracing?
      return false
    else
      return true
    end
  end

  ##
  # tracing_layer?
  #
  # Queries the thread local variable about the current
  # layer being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  def tracing_layer?(layer)
    AppOpticsAPM.layer == layer.to_sym
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
    unless AppOpticsAPM.layer_op.nil? || AppOpticsAPM.layer_op.is_a?(Array)
      AppOpticsAPM.logger.error('[appopticsapm/logging] INTERNAL: layer_op should be nil or an array, please report to support@appoptics.com')
      return false
    end

    return false if AppOpticsAPM.layer_op.nil? || AppOpticsAPM.layer_op.empty? || !operation.respond_to?(:to_sym)
    AppOpticsAPM.layer_op.last == operation.to_sym
  end

  # TODO ME review use of these boolean statements
  # ____ they should now be handled by TransactionSettings,
  # ____ because there can be exceptions to :enabled and :disabled

  ##
  # Returns true if the tracing_mode is set to :enabled.
  # False otherwise
  #
  def tracing_enabled?
    AppOpticsAPM::Config[:tracing_mode] &&
      [:enabled, :always].include?(AppOpticsAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if the tracing_mode is set to :disabled.
  # False otherwise
  #
  def tracing_disabled?
    AppOpticsAPM::Config[:tracing_mode] &&
      [:disabled, :never].include?(AppOpticsAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    return false if !AppOpticsAPM.loaded # || AppOpticsAPM.tracing_disabled?
    AppOpticsAPM::Context.isSampled
  end

  def heroku?
    ENV.key?('APPOPTICS_URL')
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
  # (Oboe_metal, JOboe_metal (JRuby), Heroku_metal)
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

module AppOpticsAPM
  extend AppOpticsAPMBase
end

# Setup an alias so we don't bug users
# about single letter capitalization
AppopticsAPM = AppOpticsAPM
AppOpticsApm = AppOpticsAPM
AppopticsApm = AppOpticsAPM
