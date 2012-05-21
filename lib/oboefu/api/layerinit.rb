module Oboe
  module API
    module LayerInit

      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer)
        force_trace do
          start_trace(layer, { '__Init' => 1, 'Version' => Oboe::Version::STRING }) { }
        end
      end

      def force_trace
        saved_mode = Oboe::Config[:tracing_mode]
        Oboe::Config[:tracing_mode] = 'always'
        result = yield
        Oboe::Config[:tracing_mode] = saved_mode
        result
      end
    end

    module LayerInitNoop
      def report_init(layer)
      end

      def force_trace
        yield
      end
    end
  end
end
