# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module API
    ##
    # Provides methods related to layer initialization and reporting
    module LayerInit
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer = :rack)
        # Don't send __Init in test or if we're
        # isn't fully loaded (e.g. missing c-extension)
        return if ENV.key?('APPOPTICS_GEM_TEST') || !AppOpticsAPM.loaded

        platform_info = AppOpticsAPM::Util.build_init_report
        log_init(layer, platform_info)
      end

      ##
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        AppOpticsAPM.logger.warn 'AppOpticsAPM::API::LayerInit.force_trace has been deprecated and will be ' \
                         'removed in a subsequent version.'

        saved_mode = AppOpticsAPM::Config[:tracing_mode]
        AppOpticsAPM::Config[:tracing_mode] = :always
        yield
      ensure
        AppOpticsAPM::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
