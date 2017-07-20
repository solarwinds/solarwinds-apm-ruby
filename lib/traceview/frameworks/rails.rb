# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Rails
    module Helpers
      extend ActiveSupport::Concern if defined?(::Rails) and ::Rails::VERSION::MAJOR > 2

      def traceview_rum_header
        TraceView.logger.warn '[traceview/warn] Note that traceview_rum_header is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_header, :traceview_rum_header

      def traceview_rum_footer
        TraceView.logger.warn '[traceview/warn] Note that traceview_rum_footer is deprecated.  It is now a no-op and should be removed from your application code.'
        return ''
      end
      alias_method :oboe_rum_footer, :traceview_rum_footer
    end # Helpers

    def self.load_initializer
      # Force load the TraceView Rails initializer if there is one
      # Prefer traceview.rb but give priority to the legacy tracelytics.rb if it exists
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
        tr_initializer = "#{rails_root}/config/initializers/traceview.rb"
      end
      require tr_initializer if File.exist?(tr_initializer)
    end

    def self.load_instrumentation
      # Load the Rails specific instrumentation
      require 'traceview/frameworks/rails/inst/action_controller'
      require 'traceview/frameworks/rails/inst/action_view'
      require 'traceview/frameworks/rails/inst/action_view_2x'
      require 'traceview/frameworks/rails/inst/action_view_30'
      require 'traceview/frameworks/rails/inst/active_record'

      TraceView.logger.info "TraceView gem #{TraceView::Version::STRING} successfully loaded."
    end

    def self.include_helpers
      # TBD: This would make the helpers available to controllers which is occasionally desired.
      # ActiveSupport.on_load(:action_controller) do
      #   include TraceView::Rails::Helpers
      # end
      if ::Rails::VERSION::MAJOR > 2
        ActiveSupport.on_load(:action_view) do
          include TraceView::Rails::Helpers
        end
      else
        ActionView::Base.send :include, TraceView::Rails::Helpers
      end
    end
  end # Rails
end # TraceView

if defined?(::Rails)
  require 'traceview/inst/rack'

  if ::Rails::VERSION::MAJOR > 2
    module TraceView
      class Railtie < ::Rails::Railtie
        initializer 'traceview.helpers' do
          TraceView::Rails.include_helpers
        end

        initializer 'traceview.rack' do |app|
          TraceView.logger.info '[traceview/loading] Instrumenting rack' if TraceView::Config[:verbose]
          app.config.middleware.insert 0, TraceView::Rack
        end

        config.after_initialize do
          TraceView.logger = ::Rails.logger if ::Rails.logger && !ENV.key?('TRACEVIEW_GEM_TEST')

          TraceView::Inst.load_instrumentation
          TraceView::Rails.load_instrumentation

          # Report __Init after fork when in Heroku
          TraceView::API.report_init unless TraceView.heroku?
        end
      end
    end
  else
    TraceView.logger = ::Rails.logger if ::Rails.logger

    TraceView::Rails.load_initializer

    Rails.configuration.after_initialize do
      TraceView.logger.info '[traceview/loading] Instrumenting rack' if TraceView::Config[:verbose]
      Rails.configuration.middleware.insert 0, 'TraceView::Rack'

      TraceView::Inst.load_instrumentation
      TraceView::Rails.load_instrumentation
      TraceView::Rails.include_helpers

      # Report __Init after fork when in Heroku
      TraceView::API.report_init unless TraceView.heroku?
    end
  end
end
