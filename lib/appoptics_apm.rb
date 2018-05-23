# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Backward compatibility for supported environment variables
ENV['APPOPTICS_GEM_VERBOSE'] = ENV['OBOE_GEM_VERBOSE'] if ENV.key?('OBOE_GEM_VERBOSE')
ENV['APPOPTICS_GEM_TEST']    = ENV['OBOE_GEM_TEST']    if ENV.key?('OBOE_GEM_TEST')

begin
  require 'openssl'
  require 'appoptics_apm/version'
  require 'appoptics_apm/thread_local'
  require 'appoptics_apm/logger'
  require 'appoptics_apm/util'
  require 'appoptics_apm/xtrace'
  require 'appoptics_apm/support'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'appoptics_apm/base'
    AppOpticsAPM.loaded = false

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      elsif RUBY_PLATFORM =~ /linux/
        require 'oboe_metal.so'
        require 'oboe_metal.rb'  # sets AppOpticsAPM.loaded = true  if successful
      else
        $stderr.puts '==================================================================='
        $stderr.puts "AppOptics warning: Platform #{RUBY_PLATFORM} not yet supported."
        $stderr.puts 'see: https://docs.appoptics.com/kb/apm_tracing/supported_platforms/'
        $stderr.puts 'Tracing disabled.'
        $stderr.puts 'Contact support@appoptics.com if this is unexpected.'
        $stderr.puts '==================================================================='
      end
    rescue LoadError
      unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_APPOPTICS_WARNING']
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing AppOpticsAPM libraries.  Tracing disabled.'
        $stderr.puts 'See: https://docs.appoptics.com/kb/apm_tracing/ruby/'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'appoptics_apm/config'
  AppOpticsAPM::Config.load_config_file

  require 'appoptics_apm/loading'
  require 'appoptics_apm/legacy_method_profiling'
  require 'appoptics_apm/method_profiling'

  if AppOpticsAPM.loaded
    require 'appoptics_apm/instrumentation'

    # Frameworks
    require 'appoptics_apm/frameworks/rails'
    require 'appoptics_apm/frameworks/sinatra'
    require 'appoptics_apm/frameworks/padrino'
    require 'appoptics_apm/frameworks/grape'
  else
    require 'appoptics_apm/noop/context'
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
