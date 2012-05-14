# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  # The following is done for compatability with older versions of oboe and
  # oboe_fu (0.2.x)
  if not defined?(Oboe::Config)
    Config = {
        :tracing_mode => "through",
        :reporter_host => "127.0.0.1",
        :sampling_rate => 3e5
    }
  end

  class << Config 
    def always?
      self[:tracing_mode].to_s == "always"
    end
  
    def never?
      self[:tracing_mode].to_s == "never"
    end
  
    def tracing?
      Oboe::Context.isValid and not never?
    end
  
    def start?
      not Oboe::Context.isValid and always?
    end

    def sample?
      # Note that this the only point in the code that currently does and
      # should ever read the sampling rate. When autopilot is released, modify
      # the line below and that line only.
      self[:sampling_rate].to_i < rand(1e6)
    end
  end
end
