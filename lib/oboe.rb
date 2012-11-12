# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
          
begin
  require 'oboe_metal.so'
  require 'rbconfig'
  require 'oboe_metal'
  require 'oboe/config'
  require 'oboe/loading'

rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
end
