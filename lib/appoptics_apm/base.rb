# Copyright (c) 2016 SolarWinds, LLC.
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

APPOPTICS_STR_BLANK = ''.freeze
APPOPTICS_STR_LAYER = 'Layer'.freeze
APPOPTICS_STR_LABEL = 'Label'.freeze

# Used in tests to store local trace data
TRACE_FILE = '/tmp/appoptics_traces.bson'.freeze

##
# This module is the base module for the various implementations of AppOpticsAPM reporting.
# Current variations as of 2014-09-10 are a c-extension, JRuby (using AppOpticsAPM Java
# instrumentation) and a Heroku c-extension (with embedded tracelyzer)
module AppOpticsAPMBase
  extend ::AppOpticsAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded
  thread_local :sample_source
  thread_local :sample_rate
  thread_local :layer
  thread_local :layer_op
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
  # JAppOpticsAPM has already initiated tracing.  In this case, we shouldn't
  # pickup the X-Trace context in the X-Trace header and we shouldn't
  # set the outgoing response X-Trace header or clear context.
  # Yeah I know.  Yuck.

  # Occurs only on Jruby.  Indicates that Joboe (the java instrumentation)
  # has already started tracing before it hit the JRuby instrumentation.
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
  # <operation> can be a single symbol or an array of symbols that
  # will be checked against.
  #
  # In such cases, we only want to trace the outermost operation.
  #
  def tracing_layer_op?(operation)
    if operation.is_a?(Array)
      operation.include?(AppOpticsAPM.layer_op)
    else
      AppOpticsAPM.layer_op == operation.to_sym
    end
  end

  ##
  # Returns true if the tracing_mode is set to always.
  # False otherwise
  #
  def always?
    AppOpticsAPM::Config[:tracing_mode] &&
      AppOpticsAPM::Config[:tracing_mode].to_sym == :always
  end

  ##
  # Returns true if the tracing_mode is set to never.
  # False otherwise
  #
  def never?
    AppOpticsAPM::Config[:tracing_mode] &&
      AppOpticsAPM::Config[:tracing_mode].to_sym == :never
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    return false if !AppOpticsAPM.loaded || AppOpticsAPM.never?
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
  # Debugging helper method
  #
  def pry!
    # Only valid for development or test environments
    env = ENV['RACK_ENV'] || ENV['RAILS_ENV']
    return unless %w(development, test).include? env

    if RUBY_VERSION > '1.9.3'
      require 'pry'
      require 'pry-byebug'

      if defined?(PryByebug)
        Pry.commands.alias_command 'c', 'continue'
        Pry.commands.alias_command 's', 'step'
        Pry.commands.alias_command 'n', 'next'
        Pry.commands.alias_command 'f', 'finish'

        Pry::Commands.command(/^$/, 'repeat last command') do
          _pry_.run_command Pry.history.to_a.last
        end
      end

      byebug
    else
      require 'ruby-debug'; debugger
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
Appoptics = AppOpticsAPM
AO = AppOpticsAPM
