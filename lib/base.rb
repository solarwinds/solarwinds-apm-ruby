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

module OboeBase
  attr_accessor :reporter
  attr_accessor :loaded
  attr_accessor :sample_source
  attr_accessor :sample_rate

  def self.included(cls)
    self.loaded = true
  end
  
  def always?
    Oboe::Config[:tracing_mode].to_s == "always"
  end
  
  def never?
    Oboe::Config[:tracing_mode].to_s == "never"
  end

  def passthrough?
    ["always", "through"].include?(Oboe::Config[:tracing_mode])
  end
  
  def through?
    Oboe::Config[:tracing_mode] == "through"
  end
  
  def tracing?
    return false unless Oboe.loaded

    Oboe::Context.isValid and not Oboe.never?
  end
  
  def log(layer, label, options = {})
    Context.log(layer, label, options = options)
  end

  ##
  # These methods should be implemented by the descendants
  # (Oboe_metal, Oboe_metal (JRuby), Heroku_metal)
  #
  def sample?(opts = {})
    raise "sample? should be implemented by metal layer."
  end
  
  def log(layer, label, options = {})
    raise "log should be implemented by metal layer."
  end
    
  def set_tracing_mode(mode)
    raise "set_tracing_mode should be implemented by metal layer."
  end
  
  def set_sample_rate(rate)
    raise "set_sample_rate should be implemented by metal layer."
  end
end

