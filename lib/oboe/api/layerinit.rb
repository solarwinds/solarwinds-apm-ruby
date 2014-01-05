# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    module LayerInit
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer)
        platform_info = { '__Init' => 1 }
        
        begin
          platform_info['Force']                   = true
          platform_info['Ruby.Platform.Version']   = RUBY_PLATFORM
          platform_info['Ruby.Version']            = RUBY_VERSION
          platform_info['Ruby.Oboe.Version']       = ::Oboe::Version::STRING
          platform_info['Ruby.OboeHeroku.Version'] = ::OboeHeroku::Version::STRING if defined?(::OboeHeroku)

          # Report the framework in use
          platform_info['Ruby.Rails.Version'] = "Rails-#{::Rails.version}"  if defined?(::Rails)
          platform_info['Ruby.Grape.Version'] = "Grape-#{::Grape::VERSION}" if defined?(::Grape)
          platform_info['Ruby.Cramp.Version'] = "Cramp-#{::Cramp::VERSION}" if defined?(::Cramp)

          if defined?(::Padrino)
            platform_info['Ruby.Padrino.Version'] = "Padrino-#{::Padrino::VERSION}"
          elsif defined?(::Sinatra)
            platform_info['Ruby.Sinatra.Version'] = "Sinatra-#{::Sinatra::VERSION}"
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
          else
            platform_info['Ruby.AppContainer.Version'] = "Unknown"
          end
        rescue
        end

        start_trace(layer, nil, platform_info) { }
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
