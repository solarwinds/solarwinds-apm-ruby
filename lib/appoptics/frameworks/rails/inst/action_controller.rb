# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
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
        AppOptics.logger.debug "[appoptics/debug] Error searching Rails handlers: #{e.message}"
        return false
      end

      #
      # log_rails_error?
      #
      # Determins whether we should log a raised exception to the
      # AppOptics dashboard.  This is determined by whether the exception
      # has a rescue handler setup and the value of
      # AppOptics::Config[:report_rescued_errors]
      #
      def log_rails_error?(exception)
        # As it's perculating up through the layers...  make sure that
        # we only report it once.
        return false if exception.instance_variable_get(:@appoptics_logged)

        has_handler = has_handler?(exception)

        if !has_handler || (has_handler && AppOptics::Config[:report_rescued_errors])
          return true
        end
        false
      end

      ##
      # This method does the logging if we are tracing
      # it `wraps` around the call to the original method
      #
      def trace(layer)
        return yield unless AppOptics.tracing?
        begin
          AppOptics::API.log_entry(layer)
          yield
        rescue Exception => e
          AppOptics::API.log_exception(layer, e) if log_rails_error?(e)
          raise
        ensure
          AppOptics::API.log_exit(layer)
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
if defined?(ActionController::Base) && AppOptics::Config[:action_controller][:enabled]
  AppOptics.logger.info '[appoptics/loading] Instrumenting actioncontroller' if AppOptics::Config[:verbose]
  require "appoptics/frameworks/rails/inst/action_controller#{Rails::VERSION::MAJOR}"
  if Rails::VERSION::MAJOR >= 5
    ::ActionController::Base.send(:prepend, ::AppOptics::Inst::ActionController)
  else
    ::AppOptics::Util.send_include(::ActionController::Base, AppOptics::Inst::ActionController)
  end
end

# ActionController::API - Rails 5+ or via the rails-api gem
if defined?(ActionController::API) && AppOptics::Config[:action_controller_api][:enabled]
  AppOptics.logger.info '[appoptics/loading] Instrumenting actioncontroller api' if AppOptics::Config[:verbose]
  require "appoptics/frameworks/rails/inst/action_controller_api"
  ::ActionController::API.send(:prepend, ::AppOptics::Inst::ActionControllerAPI)
end

# vim:set expandtab:tabstop=2
