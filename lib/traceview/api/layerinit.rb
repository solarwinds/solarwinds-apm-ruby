# Copyright (c) 2013 AppNeta, Inc.
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
      def report_init(layer = 'rack')
        # Don't send __Init in development, test or if the gem
        # isn't fully loaded (e.g. missing c-extension)
        if %w(development test).include? ENV['RACK_ENV'] ||
                          ENV.key?('TRACEVIEW_GEM_TEST') ||
                          !TraceView.loaded
          return
        end

        platform_info = TraceView::Util.build_init_report

        # If already tracing, save and clear the context.  Restore it after
        # the __Init is sent
        context = nil

        if TraceView.tracing?
          context = TraceView::Context.toString
          TraceView::Context.clear
        end

        start_trace(layer, nil, platform_info.merge('Force' => true)) {}

        TraceView::Context.fromString(context) if context
      end

      ##
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        TraceView.logger.warn 'TraceView::API::LayerInit.force_trace has been deprecated and will be ' \
                         'removed in a subsequent version.'

        saved_mode = TraceView::Config[:tracing_mode]
        TraceView::Config[:tracing_mode] = 'always'
        yield
      ensure
        TraceView::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
