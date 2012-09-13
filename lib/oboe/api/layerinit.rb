module Oboe
  module API
    module LayerInit

      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer)
        force_trace do
          start_trace(layer, nil, { '__Init' => 1, 
                                    'RubyVersion'     => RUBY_VERSION, 
                                    'RailsVersion'    => Rails.version,
                                    'OboeRubyVersion' => Gem.loaded_specs['oboe'].try(:version).to_s,
                                    'OboeFuVersion'   => Gem.loaded_specs['oboe_fu'].try(:version).to_s }) { }
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
