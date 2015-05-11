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
    }
  end

  def test_get_the_lobster
    clear_all_traces

    get "/lobster"

    traces = get_all_traces
    traces.count.must_equal 3

    validate_outer_layers(traces, 'rack')

    kvs = {}
    kvs["Label"] = "entry"
    kvs["URL"] = "/lobster"
    validate_event_keys(traces[0], kvs)

    kvs.clear
    kvs["Layer"] = "rack"
    kvs["Label"] = "info"
    kvs["HTTP-Host"] = "example.org"
    kvs["Port"] = 80
    kvs["Proto"] = "http"
    kvs["Method"] = "GET"
    kvs["ClientIP"] = "127.0.0.1"
    validate_event_keys(traces[1], kvs)

    assert traces[0].has_key?('SampleRate')
    assert traces[0].has_key?('SampleSource')
    assert traces[1].has_key?('ProcessID')
    assert traces[1].has_key?('ThreadID')

    assert traces[2]["Label"] == 'exit'
    assert traces[2]["Status"] == 200

    assert last_response.ok?

    assert last_response['X-Trace']
  end

  def test_dont_trace_static_assets
    clear_all_traces

    get "/assets/static_asset.png"

    traces = get_all_traces
    assert traces.empty?

    assert last_response.status == 404
  end

  def test_must_return_xtrace_header
    clear_all_traces
    get "/lobster"
    xtrace = last_response['X-Trace']
    assert xtrace
    assert Oboe::XTrace.valid?(xtrace)
  end

  def test_log_args_when_false
    clear_all_traces

    @log_args = Oboe::Config[:rack][:log_args]
    Oboe::Config[:rack][:log_args] = false

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert Oboe::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster"

    Oboe::Config[:rack][:log_args] = @log_args
  end

  def test_log_args_when_true
    clear_all_traces

    @log_args = Oboe::Config[:rack][:log_args]
    Oboe::Config[:rack][:log_args] = true

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert Oboe::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster?blah=1"

    Oboe::Config[:rack][:log_args] = @log_args
  end
end

