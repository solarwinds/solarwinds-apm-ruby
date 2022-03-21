# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'openssl'
  require 'appoptics_apm/version'
  require 'appoptics_apm/thread_local'
  require 'appoptics_apm/logger'
  require 'appoptics_apm/util'
  require 'appoptics_apm/support_report'
  require 'appoptics_apm/base'
  SolarWindsAPM.loaded = false

  require 'appoptics_apm/config'
  SolarWindsAPM::Config.load_config_file

  begin
    if RUBY_PLATFORM == 'java'
      require '/usr/local/tracelytics/tracelyticsagent.jar'
      require 'joboe_metal'
    elsif RUBY_PLATFORM =~ /linux/
      require_relative './libappoptics_apm.so'
      require 'appoptics_apm/oboe_init_options'
      require 'oboe_metal.rb'  # sets SolarWindsAPM.loaded = true if successful
    else
      SolarWindsAPM.logger.warn '==================================================================='
      SolarWindsAPM.logger.warn "AppOptics warning: Platform #{RUBY_PLATFORM} not yet supported."
      SolarWindsAPM.logger.warn 'see: https://docs.appoptics.com/kb/apm_tracing/supported_platforms/'
      SolarWindsAPM.logger.warn 'Tracing disabled.'
      SolarWindsAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      SolarWindsAPM.logger.warn '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_APPOPTICS_WARNING']
      SolarWindsAPM.logger.error '=============================================================='
      SolarWindsAPM.logger.error 'Missing SolarWindsAPM libraries.  Tracing disabled.'
      SolarWindsAPM.logger.error "Error: #{e.message}"
      SolarWindsAPM.logger.error 'See: https://docs.appoptics.com/kb/apm_tracing/ruby/'
      SolarWindsAPM.logger.error '=============================================================='
    end
  end

  # appoptics_apm/loading can set SolarWindsAPM.loaded = false if the service key is not working
  require 'appoptics_apm/loading'

  if SolarWindsAPM.loaded
    require 'appoptics_apm/instrumentation'
    require 'appoptics_apm/support'

    # Frameworks
    require 'appoptics_apm/frameworks/rails'
    require 'appoptics_apm/frameworks/sinatra'
    require 'appoptics_apm/frameworks/padrino'
    require 'appoptics_apm/frameworks/grape'
  else
    SolarWindsAPM.logger.warn '=============================================================='
    SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. Tracing disabled.'
    SolarWindsAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsAPM.logger.warn 'Please check previous log messages.'
    SolarWindsAPM.logger.warn '=============================================================='
    require 'appoptics_apm/noop/context'
    require 'appoptics_apm/noop/metadata'
    require 'appoptics_apm/noop/profiling'
    require 'appoptics_apm/support/trace_string'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'appoptics_apm/ruby'

  require 'appoptics_apm/test' if ENV['APPOPTICS_GEM_TEST']
rescue => e
  $stderr.puts "[appoptics_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
