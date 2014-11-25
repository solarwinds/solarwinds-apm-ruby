# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    ##
    # Provides methods related to layer initialization and reporting
    module LayerInit
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer = 'rack')
        # Don't send __Init in development or test
        return if %w(development test).include? ENV['RACK_ENV']

        # Don't send __Init if the c-extension hasn't loaded
        return unless Oboe.loaded

        platform_info = Oboe::Util.build_init_report

        # If already tracing, save and clear the context.  Restore it after
        # the __Init is sent
        if Oboe.tracing?
          context = Oboe::Context.toString
          Oboe::Context.clear
        end

        start_trace(layer, nil, platform_info.merge('Force' => true)) {}

        Oboe::Context.fromString(context) if context
      end

      ##
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        Oboe.logger.warn 'Oboe::API::LayerInit.force_trace has been deprecated and will be ' \
                         'removed in a subsequent version.'

        saved_mode = Oboe::Config[:tracing_mode]
        Oboe::Config[:tracing_mode] = 'always'
        yield
      ensure
        Oboe::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
