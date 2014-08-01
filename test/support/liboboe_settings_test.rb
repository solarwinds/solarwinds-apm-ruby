require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'oboe/inst/rack'

unless defined?(JRUBY_VERSION)
  Oboe::Config[:tracing_mode] = 'always'
  Oboe::Config[:sample_rate] = 1e6

  class RackTestApp < Minitest::Test
    include Rack::Test::Methods

    def app
      @app = Rack::Builder.new {
        use Rack::CommonLogger
        use Rack::ShowExceptions
        use Oboe::Rack
        map "/lobster" do
          use Rack::Lint
          run Rack::Lobster.new
        end
      }
    end

    def test_localset_sample_source
      clear_all_traces

      # In case this test gets run first, sleep for a bit to give
      # liboboe a chance to download SRv1 sampling info.
      sleep 10

      get "/lobster"

      get "/lobster"

      traces = get_all_traces
      traces.count.must_equal 3

      validate_outer_layers(traces, 'rack')

      kvs = {}
      kvs["SampleRate"] = "1000000"
      kvs["SampleSource"] = OBOE_SAMPLE_RATE_SOURCE_FILE.to_s
      validate_event_keys(traces[0], kvs)

    end
  end
end
