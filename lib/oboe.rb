# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

begin
  require 'oboe/version'
  require 'oboe/thread_local'
  require 'oboe/logger'
  require 'oboe/util'
  require 'oboe/xtrace'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'oboe/base'

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      else
        require 'oboe_metal.so'
        require 'oboe_metal'
      end
    rescue LoadError
      Oboe.loaded = false

      unless ENV['RAILS_GROUP'] == 'assets'
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing TraceView libraries.  Tracing disabled.'
        $stderr.puts 'See: https://support.tv.appneta.com/solution/articles/137973'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'oboe/config'

  if Oboe.loaded
    require 'oboe/loading'
    require 'method_profiling'
    require 'oboe/instrumentation'
    require 'oboe/ruby'

    # Frameworks
    require 'oboe/frameworks/rails'   if defined?(::Rails)
    require 'oboe/frameworks/sinatra' if defined?(::Sinatra)
    require 'oboe/frameworks/padrino' if defined?(::Padrino)
    require 'oboe/frameworks/grape'   if defined?(::Grape)
  end
rescue => e
  $stderr.puts '[oboe/error] Problem loading: #{e.inspect}'
  $stderr.puts e.backtrace
end
