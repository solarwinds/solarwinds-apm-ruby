# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Rails
    module Helpers
      extend ActiveSupport::Concern if defined?(::Rails) and ::Rails::VERSION::MAJOR > 2

      def appoptics_rum_header
        AppOptics.logger.warn '[appoptics/warn] Note that appoptics_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :appoptics_rum_header

      def appoptics_rum_footer
        AppOptics.logger.warn '[appoptics/warn] Note that appoptics_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :appoptics_rum_footer
    end # Helpers

    def self.load_initializer
      # Force load the AppOptics Rails initializer if there is one
      # Prefer appoptics.rb but give priority to the legacy tracelytics.rb if it exists
      if ::Rails::VERSION::MAJOR > 2
        rails_root = ::Rails.root.to_s
      else
        rails_root = RAILS_ROOT.to_s
      end

      #
      # We've been through 3 initializer names.  Try each one.
      #
      if File.exist?("#{rails_root}/config/initializers/tracelytics.rb")
        tr_initializer = "#{rails_root}/config/initializers/tracelytics.rb"

      elsif File.exist?("#{rails_root}/config/initializers/oboe.rb")
        tr_initializer = "#{rails_root}/config/initializers/oboe.rb"

      else
        tr_initializer = "#{rails_root}/config/initializers/appoptics.rb"
      end
      require tr_initializer if File.exist?(tr_initializer)
    end

    def self.load_instrumentation
      # Load the Rails specific instrumentation
      require 'appoptics/frameworks/rails/inst/action_controller'
      require 'appoptics/frameworks/rails/inst/action_view'
      require 'appoptics/frameworks/rails/inst/action_view_2x'
      require 'appoptics/frameworks/rails/inst/action_view_30'
      require 'appoptics/frameworks/rails/inst/active_record'

      AppOptics.logger.info "AppOptics gem #{AppOptics::Version::STRING} successfully loaded."
    end

    def self.include_helpers
      # TBD: This would make the helpers available to controllers which is occasionally desired.
      # ActiveSupport.on_load(:action_controller) do
      #   include AppOptics::Rails::Helpers
      # end
      if ::Rails::VERSION::MAJOR > 2
        ActiveSupport.on_load(:action_view) do
          include AppOptics::Rails::Helpers
        end
      else
        ActionView::Base.send :include, AppOptics::Rails::Helpers
      end
    end
  end # Rails
end # AppOptics

if defined?(::Rails)
  require 'appoptics/inst/rack'

  if ::Rails::VERSION::MAJOR > 2
    module AppOptics
      class Railtie < ::Rails::Railtie
        initializer 'appoptics.helpers' do
          AppOptics::Rails.include_helpers
        end

        initializer 'appoptics.rack' do |app|
          AppOptics.logger.info '[appoptics/loading] Instrumenting rack' if AppOptics::Config[:verbose]
          app.config.middleware.insert 0, AppOptics::Rack
        end

        config.after_initialize do
          AppOptics.logger = ::Rails.logger if ::Rails.logger && !ENV.key?('APPOPTICS_GEM_TEST')

          AppOptics::Inst.load_instrumentation
          AppOptics::Rails.load_instrumentation

          # Report __Init after fork when in Heroku
          AppOptics::API.report_init unless AppOptics.heroku?
        end
      end
    end
  else
    AppOptics.logger = ::Rails.logger if ::Rails.logger

    AppOptics::Rails.load_initializer

    Rails.configuration.after_initialize do
      AppOptics.logger.info '[appoptics/loading] Instrumenting rack' if AppOptics::Config[:verbose]
      Rails.configuration.middleware.insert 0, 'AppOptics::Rack'

      AppOptics::Inst.load_instrumentation
      AppOptics::Rails.load_instrumentation
      AppOptics::Rails.include_helpers

      # Report __Init after fork when in Heroku
      AppOptics::API.report_init unless AppOptics.heroku?
    end
  end
end
