# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Backward compatibility for supported environment variables
ENV['APPOPTICS_GEM_VERBOSE'] = ENV['OBOE_GEM_VERBOSE'] if ENV.key?('OBOE_GEM_VERBOSE')
ENV['APPOPTICS_GEM_TEST']    = ENV['OBOE_GEM_TEST']    if ENV.key?('OBOE_GEM_TEST')

begin
  require 'appoptics/version'
  require 'appoptics/thread_local'
  require 'appoptics/logger'
  require 'appoptics/util'
  require 'appoptics/xtrace'
  require 'appoptics/support'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'appoptics/base'

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      else
        require "oboe_metal.so"
        require "oboe_metal.rb"
      end
    rescue LoadError
      AppOptics.loaded = false

      unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_APPOPTICS_WARNING']
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing AppOptics libraries.  Tracing disabled.'
        $stderr.puts 'See: http://bit.ly/1DaNOjw'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'appoptics/config'
  require 'appoptics/loading'
  require 'appoptics/legacy_method_profiling'
  require 'appoptics/method_profiling'

  if AppOptics.loaded
    require 'appoptics/instrumentation'

    # Frameworks
    require 'appoptics/frameworks/rails'
    require 'appoptics/frameworks/sinatra'
    require 'appoptics/frameworks/padrino'
    require 'appoptics/frameworks/grape'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'appoptics/ruby'
  require 'oboe/backward_compatibility'

  require 'appoptics/test' if ENV['APPOPTICS_GEM_TEST']
rescue => e
  $stderr.puts "[appoptics/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
