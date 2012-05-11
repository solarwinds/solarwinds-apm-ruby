module Oboe
  module API
    module LayerInit

      # Report that instrumentation for the given layer has been installed, as
      # well as the version of instrumentation and version of layer.
      #
      def report_init(layer)
        start_trace(layer, { '__Init' => 1, 'Version' => Oboe::Version::STRING }) do
        end
      end
    end

    module LayerInitNoop
      def report_init(layer)
      end
    end
  end
end
