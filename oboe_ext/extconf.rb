# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'mkmf'

if RUBY_PLATFORM =~ /darwin/
  $stderr.puts "Error: native extension disabled on OS X. This will not work."
  exit 1
end

unless RUBY_PLATFORM =~ /linux/
  $stderr.puts "Error: The oboe gem will only run under linux currently."
  exit 1
end

exit 1 unless have_library('liboboe')

$libs = append_library($libs, "oboe")
$libs = append_library($libs, "stdc++")

$CFLAGS << " #{ENV["CFLAGS"]}"
$CPPFLAGS << " #{ENV["CPPFLAGS"]}"
$LIBS << " #{ENV["LIBS"]}"

cpp_command('g++') if RUBY_VERSION < '1.9'
create_makefile('oboe_ext')

