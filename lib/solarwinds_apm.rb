# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'openssl'
  require 'solarwinds_apm/version'
  require 'solarwinds_apm/thread_local'
  require 'solarwinds_apm/logger'
  require 'solarwinds_apm/util'
  require 'solarwinds_apm/support_report'
  require 'solarwinds_apm/base'
  SolarWindsAPM.loaded = false

  require 'solarwinds_apm/config'
  SolarWindsAPM::Config.load_config_file

  begin
    if RUBY_PLATFORM =~ /linux/
      require_relative './libsolarwinds_apm.so'
      require 'solarwinds_apm/oboe_init_options'
      require 'oboe_metal.rb'  # sets SolarWindsAPM.loaded = true if successful
    else
      SolarWindsAPM.logger.warn '==================================================================='
      SolarWindsAPM.logger.warn "SolarWindsAPM warning: Platform #{RUBY_PLATFORM} not yet supported."
      SolarWindsAPM.logger.warn 'see: https://docs.appoptics.com/kb/apm_tracing/supported_platforms/'
      SolarWindsAPM.logger.warn 'Tracing disabled.'
      SolarWindsAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      SolarWindsAPM.logger.warn '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' or ENV['SW_APM_NO_LIBRARIES_WARNING']
      SolarWindsAPM.logger.error '=============================================================='
      SolarWindsAPM.logger.error 'Missing SolarWindsAPM libraries.  Tracing disabled.'
      SolarWindsAPM.logger.error "Error: #{e.message}"
      SolarWindsAPM.logger.error 'See: https://docs.appoptics.com/kb/apm_tracing/ruby/'
      SolarWindsAPM.logger.error '=============================================================='
    end
  end

  # solarwinds_apm/loading can set SolarWindsAPM.loaded = false if the service key is not working
  require 'solarwinds_apm/loading'

  if SolarWindsAPM.loaded
    require 'solarwinds_apm/instrumentation'
    require 'solarwinds_apm/support'

    # Frameworks
    require 'solarwinds_apm/frameworks/rails'
    require 'solarwinds_apm/frameworks/sinatra'
    require 'solarwinds_apm/frameworks/padrino'
    require 'solarwinds_apm/frameworks/grape'
  else
    SolarWindsAPM.logger.warn '=============================================================='
    SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. Tracing disabled.'
    SolarWindsAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsAPM.logger.warn 'Please check previous log messages.'
    SolarWindsAPM.logger.warn '=============================================================='
    require 'solarwinds_apm/noop/context'
    require 'solarwinds_apm/noop/metadata'
    require 'solarwinds_apm/noop/profiling'
    require 'solarwinds_apm/support/trace_string'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'solarwinds_apm/ruby'

  require 'solarwinds_apm/test' if ENV['SW_APM_GEM_TEST']
rescue => e
  $stderr.puts "[solarwinds_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
