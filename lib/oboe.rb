# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

begin
  require 'rbconfig'
  require 'logger'
  
  require 'oboe/logger'
  require 'oboe/util'
  require 'oboe/config'

  # If Oboe_metal is already defined then we are in a PaaS environment
  # with an alternate metal (such as Heroku: see the oboe-heroku gem)
  unless defined?(Oboe_metal)
    if RUBY_PLATFORM == 'java'
      require '/usr/local/tracelytics/tracelyticsagent.jar'
      require 'joboe_metal'
    else
      require 'oboe_metal.so'
      require 'oboe_metal'
    end
  end

  require 'oboe/loading'
  require 'method_profiling'
  require 'oboe/instrumentation'
  require 'oboe/ruby'

  # Frameworks
  require 'oboe/frameworks/rails' if defined?(::Rails)

rescue LoadError
  $stderr.puts "=============================================================="
  $stderr.puts "Missing TraceView libraries.  Tracing disabled."
  $stderr.puts "See: https://support.tv.appneta.com/solution/articles/137973" 
  $stderr.puts "=============================================================="
rescue Exception => e
  $stderr.puts "[oboe/error] Problem loading: #{e.inspect}"
end
