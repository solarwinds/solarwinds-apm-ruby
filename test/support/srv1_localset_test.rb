require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'oboe/inst/rack'

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
      run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
    }
  end

  def test_localset_sample_source
    Oboe::Config[:tracing_mode] = 'always'
    Oboe::Config[:sample_rate] = 1e6
    clear_all_traces 

    get "/lobster"

    traces = get_all_traces
    traces.count.must_equal 3

    validate_outer_layers(traces, 'rack')

    kvs = {} 
    kvs["SampleRate"] = "1000000"
    kvs["SampleSource"] = OBOE_SAMPLE_RATE_SOURCE_FILE.to_s
    validate_event_keys(traces[1], kvs)
  end
  
  def test_sample_rate
    Oboe::Config[:tracing_mode] = 'always'
    Oboe::Config[:sample_rate] = 500000
    clear_all_traces 

    10.times do
      get "/"
    end

    traces = get_all_traces
    traces.count.between?(4, 6).must_equal true
  end
  
  def test_tracing_mode_never
    Oboe::Config[:tracing_mode] = 'never'
    clear_all_traces 

    10.times do
      get "/"
    end

    traces = get_all_traces
    traces.count.must_equal 0
  end
  
  def test_tracing_mode_through
    Oboe::Config[:tracing_mode] = 'through'
    clear_all_traces 

    10.times do
      get "/"
    end

    traces = get_all_traces
    traces.count.must_equal 0
  end
end

