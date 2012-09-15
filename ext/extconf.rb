# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'mkmf'

unless have_library('oboe')
  $stderr.puts "Error: Could not find the base liboboe libraries.  No tracing will occur."
end

$libs = append_library($libs, "oboe")
$libs = append_library($libs, "stdc++")

$CFLAGS << " #{ENV["CFLAGS"]}"
$CPPFLAGS << " #{ENV["CPPFLAGS"]}"
$LIBS << " #{ENV["LIBS"]}"

cpp_command('g++') if RUBY_VERSION < '1.9'
create_makefile('oboe_metal')

