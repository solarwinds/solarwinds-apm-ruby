# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

begin
  require 'rbconfig'
    
  # puts "Standard oboe initializing"
  unless defined?(Oboe_metal)
    # puts "using native oboe metal"
    if RUBY_PLATFORM == 'java'
      require '/usr/local/tracelytics/tracelyticsagent.jar'
      require 'joboe_metal'
    else
      require 'oboe_metal.so'
      require 'oboe_metal'
    end
  else
    # puts "Using PaaS Oboe Metal"
    # Do Nothing - use the Oboe_metal from oboe-heroku gem
  end
  require 'oboe/config'
  require 'oboe/loading'
  require 'method_profiling'
  require 'oboe/instrumentation'
  require 'oboe/ruby'

  # Frameworks
  require 'oboe/frameworks/rails' if defined?(::Rails)

rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
end
