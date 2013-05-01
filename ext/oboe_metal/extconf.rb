# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'mkmf'
require 'rbconfig'

dir_config('oboe')

# Check if we're running in JRuby
if RbConfig::CONFIG.has_key?('arch')
  # nil meaning java string not found
  jruby = (RbConfig::CONFIG['arch'] =~ /java/i) != nil
else
  jruby = false
end

if ENV.has_key?('TRACEVIEW_URL') or jruby
  # FIXME: Check that the oboe-heroku gem is in use and
  #        output a warning if not found

  # We are running in Heroku or jruby - quietly go no-op and
  # leave the platform work to oboe-heroku/joboe_metal 
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

