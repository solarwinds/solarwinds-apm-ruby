# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'mkmf'
dir_config('oboe')

if have_library('oboe')
  $libs = append_library($libs, "oboe")
  $libs = append_library($libs, "stdc++")

  $CFLAGS << " #{ENV["CFLAGS"]}"
  $CPPFLAGS << " #{ENV["CPPFLAGS"]}"
  $LIBS << " #{ENV["LIBS"]}"

  cpp_command('g++') if RUBY_VERSION < '1.9'
  create_makefile('oboe_metal', 'src')
else
  $stderr.puts "Error: Could not find the base liboboe libraries.  No tracing will occur."
  create_makefile('oboe_noop', 'noop')
end

