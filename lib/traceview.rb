# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

begin
  require 'traceview/version'
  require 'traceview/thread_local'
  require 'traceview/logger'
  require 'traceview/util'
  require 'traceview/xtrace'
  require 'traceview/support'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'traceview/base'

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      else
        require "oboe_metal.so"
        require "oboe_metal.rb"
      end
    rescue LoadError
      TraceView.loaded = false

      unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_TRACEVIEW_WARNING']
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing TraceView libraries.  Tracing disabled.'
        $stderr.puts 'See: http://bit.ly/1DaNOjw'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'traceview/config'
  require 'traceview/loading'

  if TraceView.loaded
    require 'traceview/method_profiling'
    require 'traceview/instrumentation'

    # Frameworks
    require 'traceview/frameworks/rails'
    require 'traceview/frameworks/sinatra'
    require 'traceview/frameworks/padrino'
    require 'traceview/frameworks/grape'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'traceview/ruby'
  require 'oboe/backward_compatibility'
rescue => e
  $stderr.puts "[traceview/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
