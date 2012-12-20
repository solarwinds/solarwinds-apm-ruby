module Oboe
  module API
    module LayerInit
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer)
        platform_info                  = { '__Init' => 1 }
        platform_info['RubyVersion']   = RUBY_VERSION
        platform_info['RailsVersion']  = ::Rails.version if defined?(Rails)
        platform_info['OboeVersion']   = Gem.loaded_specs['oboe'].try(:version).to_s

        force_trace do
          start_trace(layer, nil, platform_info) { }
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
  end
end
