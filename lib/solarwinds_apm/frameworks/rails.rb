# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require_relative '../../../lib/solarwinds_apm/inst/logger_formatter'

module SolarWindsAPM
  module Rails
    module Helpers
      extend ActiveSupport::Concern if defined?(::Rails)

      # Deprecated
      # no usages
      def appoptics_rum_header
        SolarWindsAPM.logger.warn '[solarwinds_apm/warn] Note that appoptics_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :appoptics_rum_header

      # Deprecated
      def appoptics_rum_footer
        SolarWindsAPM.logger.warn '[solarwinds_apm/warn] Note that appoptics_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :appoptics_rum_footer
    end # Helpers

    def self.load_initializer
      # Force load the SolarWindsAPM Rails initializer if there is one
      # Prefer solarwinds_apm.rb but give priority to the legacy tracelytics.rb if it exists
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
        tr_initializer = "#{rails_root}/config/initializers/solarwinds_apm.rb"
      end
      require tr_initializer if File.exist?(tr_initializer)
    end

    def self.load_instrumentation
      # Load the Rails specific instrumentation
      require 'solarwinds_apm/frameworks/rails/inst/action_controller'
      require 'solarwinds_apm/frameworks/rails/inst/action_view'
      require 'solarwinds_apm/frameworks/rails/inst/active_record'
      require 'solarwinds_apm/frameworks/rails/inst/logger_formatters'

      SolarWindsAPM.logger.info "[solarwinds_apm/rails] SolarWindsAPM gem #{SolarWindsAPM::Version::STRING} successfully loaded."
    end

    def self.include_helpers
      # TBD: This would make the helpers available to controllers which is occasionally desired.
      # ActiveSupport.on_load(:action_controller) do
      #   include SolarWindsAPM::Rails::Helpers
      # end
      ActiveSupport.on_load(:action_view) do
        include SolarWindsAPM::Rails::Helpers
      end
    end
  end # Rails
end # SolarWindsAPM

if defined?(::Rails)
  require 'solarwinds_apm/inst/rack'

  module SolarWindsAPM
    class Railtie < ::Rails::Railtie
      initializer 'solarwinds_apm.helpers' do
        SolarWindsAPM::Rails.include_helpers
      end

      initializer 'solarwinds_apm.controller', before: 'wicked_pdf.register' do
        SolarWindsAPM::Rails.load_instrumentation
      end

      initializer 'solarwinds_apm.rack' do |app|
        SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting rack' if SolarWindsAPM::Config[:verbose]
        app.config.middleware.insert 0, SolarWindsAPM::Rack
      end

      config.after_initialize do
        SolarWindsAPM.logger = ::Rails.logger if ::Rails.logger && !ENV.key?('SW_AMP_GEM_TEST')

        SolarWindsAPM::Inst.load_instrumentation
        # SolarWindsAPM::Rails.load_instrumentation

        # Report __Init after fork when in Heroku
        SolarWindsAPM::API.report_init unless SolarWindsAPM.heroku?
      end
    end
  end
end
