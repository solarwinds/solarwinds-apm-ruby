# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Rails
    module Helpers
      extend ActiveSupport::Concern if defined?(::Rails) and ::Rails::VERSION::MAJOR > 2

      def appoptics_rum_header
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Note that appoptics_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :appoptics_rum_header

      def appoptics_rum_footer
        AppOpticsAPM.logger.warn '[appoptics_apm/warn] Note that appoptics_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :appoptics_rum_footer
    end # Helpers

    def self.load_initializer
      # Force load the AppOpticsAPM Rails initializer if there is one
      # Prefer appoptics_apm.rb but give priority to the legacy tracelytics.rb if it exists
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
        tr_initializer = "#{rails_root}/config/initializers/appoptics_apm.rb"
      end
      require tr_initializer if File.exist?(tr_initializer)
    end

    def self.load_instrumentation
      # Load the Rails specific instrumentation
      require 'appoptics_apm/frameworks/rails/inst/action_controller'
      require 'appoptics_apm/frameworks/rails/inst/action_view'
      require 'appoptics_apm/frameworks/rails/inst/action_view_2x'
      require 'appoptics_apm/frameworks/rails/inst/action_view_30'
      require 'appoptics_apm/frameworks/rails/inst/active_record'

      AppOpticsAPM.logger.info "AppOpticsAPM gem #{AppOpticsAPM::Version::STRING} successfully loaded."
    end

    def self.include_helpers
      # TBD: This would make the helpers available to controllers which is occasionally desired.
      # ActiveSupport.on_load(:action_controller) do
      #   include AppOpticsAPM::Rails::Helpers
      # end
      if ::Rails::VERSION::MAJOR > 2
        ActiveSupport.on_load(:action_view) do
          include AppOpticsAPM::Rails::Helpers
        end
      else
        ActionView::Base.send :include, AppOpticsAPM::Rails::Helpers
      end
    end
  end # Rails
end # AppOpticsAPM

if defined?(::Rails)
  require 'appoptics_apm/inst/rack'

  if ::Rails::VERSION::MAJOR > 2
    module AppOpticsAPM
      class Railtie < ::Rails::Railtie
        initializer 'appoptics_apm.helpers' do
          AppOpticsAPM::Rails.include_helpers
        end

        initializer 'appoptics_apm.rack' do |app|
          AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting rack' if AppOpticsAPM::Config[:verbose]
          app.config.middleware.insert 0, AppOpticsAPM::Rack
        end

        config.after_initialize do
          AppOpticsAPM.logger = ::Rails.logger if ::Rails.logger && !ENV.key?('APPOPTICS_GEM_TEST')

          AppOpticsAPM::Inst.load_instrumentation
          AppOpticsAPM::Rails.load_instrumentation

          # Report __Init after fork when in Heroku
          AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
        end
      end
    end
  else
    AppOpticsAPM.logger = ::Rails.logger if ::Rails.logger

    AppOpticsAPM::Rails.load_initializer

    Rails.configuration.after_initialize do
      AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting rack' if AppOpticsAPM::Config[:verbose]
      Rails.configuration.middleware.insert 0, 'AppOpticsAPM::Rack'

      AppOpticsAPM::Inst.load_instrumentation
      AppOpticsAPM::Rails.load_instrumentation
      AppOpticsAPM::Rails.include_helpers

      # Report __Init after fork when in Heroku
      AppOpticsAPM::API.report_init unless AppOpticsAPM.heroku?
    end
  end
end
