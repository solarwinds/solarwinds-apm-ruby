# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
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
        return if ENV.key?('TRACEVIEW_GEM_TEST') || !TraceView.loaded

        platform_info = TraceView::Util.build_init_report
        log_init(layer, platform_info)
      end

      ##
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        TraceView.logger.warn 'TraceView::API::LayerInit.force_trace has been deprecated and will be ' \
                         'removed in a subsequent version.'

        saved_mode = TraceView::Config[:tracing_mode]
        TraceView::Config[:tracing_mode] = :always
        yield
      ensure
        TraceView::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
