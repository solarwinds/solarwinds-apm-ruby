# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
require 'mkmf'
require 'rbconfig'

# Check if we're running in JRuby
if RbConfig::CONFIG.has_key?('arch')
  # nil meaning java string not found
  jruby = (RbConfig::CONFIG['arch'] =~ /java/i) != nil
else
  jruby = false
end

dir_config('oboe')

if jruby or ENV.has_key?('TRACEVIEW_URL') 
  # Build the noop extension under JRuby and Heroku.
  # The oboe-heroku gem builds it's own c extension which links to
  # libs specific to a Heroku dyno
  # FIXME: For JRuby we need to remove the c extension entirely
  create_makefile('oboe_noop', 'noop')

elsif have_library('oboe') 

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

