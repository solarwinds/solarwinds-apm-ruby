# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

begin
  require 'oboe_metal.so'
  require 'pp'
  require 'rbconfig'
  require 'oboe_metal'
rescue LoadError
  puts "Unsupported Tracelytics environment (no libs).  Going No-op."
  require 'oboe_metal_noop'
end
