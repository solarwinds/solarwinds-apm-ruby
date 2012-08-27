module Oboe
  module API
    module LayerInit

      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer)
        force_trace do
          start_trace(layer, nil, { '__Init' => 1, 'OboeFuVersion' => Oboe::Version::STRING,
                                    'RubyVersion' => RUBY_VERSION, 'RailsVersion' => Rails.version,
                                    'OboeRubyVersion' => '0.2.4' }) { }
        end
      end

      def force_trace
        saved_mode = Oboe::Config[:tracing_mode]
        Oboe::Config[:tracing_mode] = 'always'
        yield
      ensure
        Oboe::Config[:tracing_mode] = saved_mode
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
