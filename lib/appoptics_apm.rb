# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'openssl'
  require 'appoptics_apm/version'
  require 'appoptics_apm/thread_local'
  require 'appoptics_apm/logger'
  require 'appoptics_apm/util'
  require 'appoptics_apm/xtrace'
  require 'appoptics_apm/support_report'
  require 'appoptics_apm/base'
  AppOpticsAPM.loaded = false

  require 'appoptics_apm/config'
  AppOpticsAPM::Config.load_config_file

  begin
    if RUBY_PLATFORM == 'java'
      require '/usr/local/tracelytics/tracelyticsagent.jar'
      require 'joboe_metal'
    elsif RUBY_PLATFORM =~ /linux/
      require_relative './libappoptics_apm.so'
      require 'appoptics_apm/oboe_init_options'
      require 'oboe_metal.rb'  # sets AppOpticsAPM.loaded = true if successful
    else
      AppOpticsAPM.logger.warn '==================================================================='
      AppOpticsAPM.logger.warn "AppOptics warning: Platform #{RUBY_PLATFORM} not yet supported."
      AppOpticsAPM.logger.warn 'see: https://docs.appoptics.com/kb/apm_tracing/supported_platforms/'
      AppOpticsAPM.logger.warn 'Tracing disabled.'
      AppOpticsAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      AppOpticsAPM.logger.warn '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_APPOPTICS_WARNING']
      AppOpticsAPM.logger.error '=============================================================='
      AppOpticsAPM.logger.error 'Missing AppOpticsAPM libraries.  Tracing disabled.'
      AppOpticsAPM.logger.error "Error: #{e.message}"
      AppOpticsAPM.logger.error 'See: https://docs.appoptics.com/kb/apm_tracing/ruby/'
      AppOpticsAPM.logger.error '=============================================================='
    end
  end

  # appoptics_apm/loading can set AppOpticsAPM.loaded = false if the service key is not working
  require 'appoptics_apm/loading'

  if AppOpticsAPM.loaded
    require 'appoptics_apm/instrumentation'
    require 'appoptics_apm/support/profiling'
    require 'appoptics_apm/support/transaction_metrics'
    require 'appoptics_apm/support/x_trace_options'

    # Frameworks
    require 'appoptics_apm/frameworks/rails'
    require 'appoptics_apm/frameworks/sinatra'
    require 'appoptics_apm/frameworks/padrino'
    require 'appoptics_apm/frameworks/grape'
  else
    AppOpticsAPM.logger.warn '=============================================================='
    AppOpticsAPM.logger.warn 'AppOpticsAPM not loaded. Tracing disabled.'
    AppOpticsAPM.logger.warn 'There may be a problem with the service key or other settings.'
    AppOpticsAPM.logger.warn 'Please check previous log messages.'
    AppOpticsAPM.logger.warn '=============================================================='
    require 'appoptics_apm/noop/context'
    require 'appoptics_apm/noop/metadata'
    require 'appoptics_apm/noop/profiling'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'appoptics_apm/ruby'

  require 'appoptics_apm/test' if ENV['APPOPTICS_GEM_TEST']
rescue => e
  $stderr.puts "[appoptics_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
