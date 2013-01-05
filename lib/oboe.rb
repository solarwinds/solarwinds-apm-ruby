# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

begin
  require 'rbconfig'
  if RUBY_PLATFORM == 'java'
    require '/usr/local/tracelytics/tracelyticsagent.jar'
    require 'joboe_metal'
  else
    require 'oboe_metal.so'
    require 'oboe_metal'
  end
  require 'method_profiling'
  require 'oboe/config'
  require 'oboe/loading'

  # Instrumentation
  require 'oboe/inst/cassandra'
  require 'oboe/inst/dalli'
  require 'oboe/inst/http'
  require 'oboe/inst/memcached'
  require 'oboe/inst/memcache'
  require 'oboe/inst/mongo'
  require 'oboe/inst/moped'
  require 'oboe/inst/rack'

  # Frameworks
  require 'oboe/frameworks/rails'

rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
end
