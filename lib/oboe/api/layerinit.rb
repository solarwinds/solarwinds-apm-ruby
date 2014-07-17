# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    module LayerInit
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer = 'rack')
        # Don't send __Init in development or test
        return if ["development", "test"].include? ENV['RACK_ENV']

        # Don't send __Init if the c-extension hasn't loaded
        return unless Oboe.loaded

        platform_info = { '__Init' => 1 }

        begin
          platform_info['Force']                   = true
          platform_info['Ruby.Platform.Version']   = RUBY_PLATFORM
          platform_info['Ruby.Version']            = RUBY_VERSION
          platform_info['Ruby.Oboe.Version']       = ::Oboe::Version::STRING
          platform_info['RubyHeroku.Oboe.Version'] = ::OboeHeroku::Version::STRING if defined?(::OboeHeroku)

          # Report the framework in use
          platform_info['Ruby.Rails.Version'] = "Rails-#{::Rails.version}"  if defined?(::Rails)
          platform_info['Ruby.Grape.Version'] = "Grape-#{::Grape::VERSION}" if defined?(::Grape)
          platform_info['Ruby.Cramp.Version'] = "Cramp-#{::Cramp::VERSION}" if defined?(::Cramp)

          if defined?(::Padrino)
            platform_info['Ruby.Padrino.Version'] = "Padrino-#{::Padrino::VERSION}"
          elsif defined?(::Sinatra)
            platform_info['Ruby.Sinatra.Version'] = "Sinatra-#{::Sinatra::VERSION}"
          end

          # Report the instrumented libraries
          platform_info['Ruby.Cassandra.Version'] = "Cassandra-#{::Cassandra.VERSION}" if defined?(::Cassandra)
          platform_info['Ruby.Dalli.Version']     = "Dalli-#{::Dalli::VERSION}"        if defined?(::Dalli)
          platform_info['Ruby.MemCache.Version']  = "MemCache-#{::MemCache::VERSION}"  if defined?(::MemCache)
          platform_info['Ruby.Moped.Version']     = "Moped-#{::Moped::VERSION}"        if defined?(::Moped)
          platform_info['Ruby.Redis.Version']     = "Redis-#{::Redis::VERSION}"        if defined?(::Redis)
          platform_info['Ruby.Resque.Version']    = "Resque-#{::Resque::VERSION}"      if defined?(::Resque)

          # Special case since the Mongo 1.x driver doesn't embed the version number in the gem directly
          if ::Gem.loaded_specs.has_key?('mongo')
            platform_info['Ruby.Mongo.Version']     = "Mongo-#{::Gem.loaded_specs['mongo'].version.to_s}"
          end

          # Report the server in use (if possible)
          if defined?(::Unicorn)
            platform_info['Ruby.AppContainer.Version'] = "Unicorn-#{::Unicorn::Const::UNICORN_VERSION}"
          elsif defined?(::Puma)
            platform_info['Ruby.AppContainer.Version'] = "Puma-#{::Puma::Const::PUMA_VERSION} (#{::Puma::Const::CODE_NAME})"
          elsif defined?(::PhusionPassenger)
            platform_info['Ruby.AppContainer.Version'] = "#{::PhusionPassenger::PACKAGE_NAME}-#{::PhusionPassenger::VERSION_STRING}"
          elsif defined?(::Thin)
            platform_info['Ruby.AppContainer.Version'] = "Thin-#{::Thin::VERSION::STRING} (#{::Thin::VERSION::CODENAME})"
          elsif defined?(::Mongrel)
            platform_info['Ruby.AppContainer.Version'] = "Mongrel-#{::Mongrel::Const::MONGREL_VERSION}"
          elsif defined?(::Mongrel2)
            platform_info['Ruby.AppContainer.Version'] = "Mongrel2-#{::Mongrel2::VERSION}"
          elsif defined?(::Trinidad)
            platform_info['Ruby.AppContainer.Version'] = "Trinidad-#{::Trinidad::VERSION}"
          elsif defined?(::WEBrick)
            platform_info['Ruby.AppContainer.Version'] = "WEBrick-#{::WEBrick::VERSION}"
          else
            platform_info['Ruby.AppContainer.Version'] = File.basename($0)
          end

        rescue StandardError, ScriptError => e
          # Also rescue ScriptError (aka SyntaxError) in case one of the expected
          # version defines don't exist

          platform_info['Error'] = "Error in layerinit: #{e.message}"

          Oboe.logger.debug "Error in layerinit: #{e.message}"
          Oboe.logger.debug e.backtrace
        end

        start_trace(layer, nil, platform_info.merge('Force' => true)) { }
      end

      ##
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        Oboe.logger.warn "Oboe::API::LayerInit.force_trace has been deprecated and will be removed in a subsequent version."

        saved_mode = Oboe::Config[:tracing_mode]
        Oboe::Config[:tracing_mode] = 'always'
        yield
      ensure
        Oboe::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
