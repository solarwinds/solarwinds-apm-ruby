# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'mkmf'
require 'rbconfig'

# Check if we're running in JRuby
jruby = defined?(JRUBY_VERSION) ? true : false

openshift = ENV.key?('OPENSHIFT_TRACEVIEW_DIR')

# When on OpenShift, set the mkmf lib paths so we have no issues linking to
# the TraceView libs.
if openshift
  tv_lib64 = "#{ENV['OPENSHIFT_TRACEVIEW_DIR']}usr/lib64"
  tv_tlyzer = "#{ENV['OPENSHIFT_TRACEVIEW_DIR']}usr/lib64/tracelyzer"

  idefault = "#{ENV['OPENSHIFT_TRACEVIEW_DIR']}usr/include"
  ldefault = "#{tv_lib64}:#{tv_tlyzer}"

  dir_config('oboe', idefault, ldefault)
else
  dir_config('oboe')
end

if jruby || ENV.key?('TRACEVIEW_URL')
  # Build the noop extension under JRuby and Heroku.
  # The oboe-heroku gem builds it's own c extension which links to
  # libs specific to a Heroku dyno
  # FIXME: For JRuby we need to remove the c extension entirely
  create_makefile('oboe_noop', 'noop')

elsif have_library('oboe', 'oboe_config_get_revision', 'oboe/oboe.h')

  $libs = append_library($libs, 'oboe')
  $libs = append_library($libs, 'stdc++')

  $CFLAGS << " #{ENV['CFLAGS']}"
  $CPPFLAGS << " #{ENV['CPPFLAGS']}"
  $LIBS << " #{ENV['LIBS']}"

  # On OpenShift user rpath to point out the TraceView libraries
  if openshift
    $LDFLAGS << " #{ENV['LDFLAGS']} -Wl,-rpath=#{tv_lib64},--rpath=#{tv_tlyzer}"
  end

  if RUBY_VERSION < '1.9'
    cpp_command('g++')
    $CPPFLAGS << '-I./src/'
  end
  create_makefile('oboe_metal', 'src')

else
  if have_library('oboe')
    $stderr.puts 'Error: The oboe gem requires an updated liboboe.  Please update your liboboe packages.'
  end

  $stderr.puts 'Error: Could not find the base liboboe libraries.  No tracing will occur.'
  create_makefile('oboe_noop', 'noop')
end

