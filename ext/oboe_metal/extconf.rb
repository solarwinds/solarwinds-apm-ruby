# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'mkmf'
require 'rbconfig'
require 'open-uri'
require 'digest'

ext_dir = File.expand_path(File.dirname(__FILE__))

# Check if we're running in JRuby
jruby = defined?(JRUBY_VERSION) ? true : false

# Set the mkmf lib paths so we have no issues linking to
# the AppOpticsAPM libs.
ao_lib_dir = File.join(ext_dir, 'lib')
ao_include = File.join(ext_dir, 'src')

# Download the appropriate liboboe from files.appoptics.com
ao_path = File.join('https://files.appoptics.com/c-lib', File.read(File.join(ao_include, 'VERSION')).chomp)
ao_arch = `ldd --version 2>&1` =~ /musl/ ? 'alpine-x86_64' : 'x86_64'
ao_clib = "liboboe-1.0-#{ao_arch}.so.0.0.0"
ao_item = File.join(ao_path, ao_clib)
ao_checksum_item = "#{ao_item}.sha256"
target = File.join(ao_lib_dir, ao_clib)

retries = 3
while retries > 0
  begin
    # download
    download = open(ao_item, 'rb')
    IO.copy_stream(download, target)

    checksum = open(ao_checksum_item, 'r').read.chomp
    target_checksum = Digest::SHA256.file(target).hexdigest

    # verify_checksum
    if target_checksum != checksum
      $stderr.puts '== ERROR ================================================================='
      $stderr.puts 'Checksum Verification failed for the c-extension of the appoptics_apm gem.'
      $stderr.puts 'appoptics_apm will not instrument the code. No tracing will occur.'
      $stderr.puts 'Contact support@appoptics.com if the problem persists.'
      $stderr.puts '=========================================================================='
      create_makefile('oboe_noop', 'noop')
      retries = 0
    else
      success = true
      retries = 0
    end
  rescue => e
    File.write(target, '')
    retries -= 1
    if retries == 0
      $stderr.puts '== ERROR =========================================================='
      $stderr.puts 'Download of the c-extension for the appoptics_apm gem failed.'
      $stderr.puts 'appoptics_apm will not instrument the code. No tracing will occur.'
      $stderr.puts 'Contact support@appoptics.com if the problem persists.'
      $stderr.puts '==================================================================='
      create_makefile('oboe_noop', 'noop')
    end
    sleep 0.5
  end
end

if success
  # Create symlinks for the AppOpticsAPM library
  File.symlink(target, File.join(ao_lib_dir, 'liboboe.so'))
  File.symlink(target, File.join(ao_lib_dir, 'liboboe-1.0.so.0'))

  dir_config('oboe', ao_include, ao_lib_dir)

  if jruby || ENV.key?('APPOPTICS_URL')
    # Build the noop extension under JRuby and Heroku.
    # The oboe-heroku gem builds it's own c extension which links to
    # libs specific to a Heroku dyno
    # FIXME: For JRuby we need to remove the c extension entirely
    create_makefile('oboe_noop', 'noop')

  elsif have_library('oboe', 'oboe_config_get_revision', 'oboe.h')

    $libs = append_library($libs, 'oboe')
    $libs = append_library($libs, 'stdc++')

    $CFLAGS << " #{ENV['CFLAGS']}"
    $CPPFLAGS << " #{ENV['CPPFLAGS']}"
    $LIBS << " #{ENV['LIBS']}"
    $LDFLAGS << " #{ENV['LDFLAGS']} -Wl,-rpath=#{ao_lib_dir}"

    if RUBY_VERSION < '1.9'
      cpp_command('g++')
      $CPPFLAGS << '-I./src/'
    end
    create_makefile('oboe_metal', 'src')

  else
    $stderr.puts   '== ERROR ========================================================='
    if have_library('oboe')
      $stderr.puts "The c-library either needs to be updated or doesn't match the OS."
      $stderr.puts 'No tracing will occur.'
    else
      $stderr.puts 'Could not find a matching c-library. No tracing will occur.'
    end
    $stderr.puts   'Contact support@appoptics.com if the problem persists.'
    $stderr.puts   '=================================================================='
    create_makefile('oboe_noop', 'noop')
  end
end
