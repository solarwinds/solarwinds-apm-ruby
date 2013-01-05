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
  require 'rbconfig'
  require 'method_profiling'
  require 'oboe/config'
  require 'oboe/loading'

  # Instrumentation
  require 'inst/cassandra'
  require 'inst/dalli'
  require 'inst/http'
  require 'inst/memcached'
  require 'inst/memcache'
  require 'inst/mongo'
  require 'inst/moped'
  require 'inst/rack'

  # Frameworks
  require 'oboe/frameworks/rails'

rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
end
