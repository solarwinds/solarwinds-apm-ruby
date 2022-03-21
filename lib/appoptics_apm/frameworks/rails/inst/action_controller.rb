# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    #
    # RailsBase
    #
    # This module contains the instrumentation code common to
    # many Rails versions.
    #
    module RailsBase

      #
      # has_handler?
      #
      # Determins if <tt>exception</tt> has a registered
      # handler via <tt>rescue_from</tt>
      #
      def has_handler?(exception)
        # Don't log exceptions if they have a rescue handler set
        has_handler = false
        rescue_handlers.detect do |klass_name, _handler|
          # Rescue handlers can be specified as strings or constant names
          klass = self.class.const_get(klass_name) rescue nil
          klass ||= klass_name.constantize rescue nil
          has_handler = exception.is_a?(klass) if klass
        end
        has_handler
      rescue => e
        SolarWindsAPM.logger.debug "[appoptics_apm/debug] Error searching Rails handlers: #{e.message}"
        return false
      end

      #
      # log_rails_error?
      #
      # Determines whether we should log a raised exception to the
      # AppOptics dashboard.  This is determined by whether the exception
      # has a rescue handler setup and the value of
      # SolarWindsAPM::Config[:report_rescued_errors]
      #
      def log_rails_error?(exception)
        # As it's perculating up through the layers...  make sure that
        # we only report it once.
        return false if exception.instance_variable_get(:@exn_logged)

        return false if has_handler?(exception) && !SolarWindsAPM::Config[:report_rescued_errors]

        true
      end

      ##
      # This method does the logging if we are tracing
      # it `wraps` around the call to the original method
      #
      # This can't use the SDK trace() method because of the log_rails_error?(e) condition
      def trace(layer)
        return yield unless SolarWindsAPM.tracing?
        begin
          SolarWindsAPM::API.log_entry(layer)
          yield
        rescue Exception => e
          SolarWindsAPM::API.log_exception(layer, e) if log_rails_error?(e)
          raise
        ensure
          SolarWindsAPM::API.log_exit(layer)
        end
      end


      #
      # render_with_appoptics
      #
      # Our render wrapper that calls 'add_logging', which will log if we are tracing
      #
      def render_with_appoptics(*args, &blk)
        trace('actionview') do
          render_without_appoptics(*args, &blk)
        end
      end
    end
  end
end

# ActionController::Base
if defined?(ActionController::Base) && SolarWindsAPM::Config[:action_controller][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting actioncontroller' if SolarWindsAPM::Config[:verbose]
  require "appoptics_apm/frameworks/rails/inst/action_controller5"
  ActionController::Base.send(:prepend, ::SolarWindsAPM::Inst::ActionController)
end

# ActionController::API
if defined?(ActionController::API) && SolarWindsAPM::Config[:action_controller_api][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting actioncontroller api' if SolarWindsAPM::Config[:verbose]
  require "appoptics_apm/frameworks/rails/inst/action_controller_api"
  ActionController::API.send(:prepend, ::SolarWindsAPM::Inst::ActionControllerAPI)
end

# vim:set expandtab:tabstop=2
