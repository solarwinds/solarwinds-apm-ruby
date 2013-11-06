# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module OboeBase
  attr_accessor :reporter
  
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

