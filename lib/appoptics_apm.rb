# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'openssl'
  require 'appoptics_apm/version'
  require 'appoptics_apm/thread_local'
  require 'appoptics_apm/logger'
  require 'appoptics_apm/util'
  require 'appoptics_apm/xtrace'
  require 'appoptics_apm/support'
  require 'appoptics_apm/base'
  AppOpticsAPM.loaded = false

  require 'appoptics_apm/config'
  AppOpticsAPM::Config.load_config_file

  begin
    if RUBY_PLATFORM == 'java'
      require '/usr/local/tracelytics/tracelyticsagent.jar'
      require 'joboe_metal'
    elsif RUBY_PLATFORM =~ /linux/
      require_relative './oboe_metal.so'
      require 'oboe_metal.rb'  # sets AppOpticsAPM.loaded = true if successful
    else
      $stderr.puts '==================================================================='
      $stderr.puts "AppOptics warning: Platform #{RUBY_PLATFORM} not yet supported."
      $stderr.puts 'see: https://docs.appoptics.com/kb/apm_tracing/supported_platforms/'
      $stderr.puts 'Tracing disabled.'
      $stderr.puts 'Contact support@appoptics.com if this is unexpected.'
      $stderr.puts '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_APPOPTICS_WARNING']
      $stderr.puts '=============================================================='
      $stderr.puts 'Missing AppOpticsAPM libraries.  Tracing disabled.'
      $stderr.puts "Error: #{e.message}"
      $stderr.puts 'See: https://docs.appoptics.com/kb/apm_tracing/ruby/'
      $stderr.puts '=============================================================='
    end
  end

  # appoptics_apm/loading can set AppOpticsAPM.loaded = false if the service key is not working
  require 'appoptics_apm/loading'
  require 'appoptics_apm/legacy_method_profiling'
  require 'appoptics_apm/method_profiling'

  if AppOpticsAPM.loaded
    # tracing mode is configured via config file but can only be set once we have oboe_metal loaded
    AppOpticsAPM.set_tracing_mode(AppOpticsAPM::Config[:tracing_mode].to_sym)
    require 'appoptics_apm/instrumentation'

    # Frameworks
    require 'appoptics_apm/frameworks/rails'
    require 'appoptics_apm/frameworks/sinatra'
    require 'appoptics_apm/frameworks/padrino'
    require 'appoptics_apm/frameworks/grape'
  else
    $stderr.puts '=============================================================='
    $stderr.puts 'AppOpticsAPM not loaded. Tracing disabled.'
    $stderr.puts 'Service Key may be wrong or missing.'
    $stderr.puts '=============================================================='
    require 'appoptics_apm/noop/context'
    require 'appoptics_apm/noop/metadata'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'appoptics_apm/ruby'
  require 'oboe/backward_compatibility'

  require 'appoptics_apm/test' if ENV['APPOPTICS_GEM_TEST']
rescue => e
  $stderr.puts "[appoptics_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
