# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'traceview/inst/rack'
require 'mocha/mini_test'

class RackTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use TraceView::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def teardown
    TraceView::Config[:tracing_mode] = :always
  end

  def test_get_the_lobster
    skip("FIXME: broken on travis only") if ENV['TRAVIS'] == "true"

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

  def test_must_return_xtrace_header
    clear_all_traces
    get "/lobster"
    xtrace = last_response['X-Trace']
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)
  end

  def test_log_args_when_false
    clear_all_traces

    @log_args = TraceView::Config[:rack][:log_args]
    TraceView::Config[:rack][:log_args] = false

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster"

    TraceView::Config[:rack][:log_args] = @log_args
  end

  def test_log_args_when_true
    clear_all_traces

    @log_args = TraceView::Config[:rack][:log_args]
    TraceView::Config[:rack][:log_args] = true

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster?blah=1"

    TraceView::Config[:rack][:log_args] = @log_args
  end

  def test_has_header_when_not_tracing
    clear_all_traces

    TraceView::Config[:tracing_mode] = :never

    get "/lobster?blah=1"

    traces = get_all_traces
    assert_equal(0, traces.size)

    assert last_response['X-Trace'], "X-Trace header is missing"
    assert not_sampled?(last_response['X-Trace']), "X-Trace sampling flag is not '00'"
  end

  def test_sends_path_in_http_span_when_no_controller
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    TraceView::Span.expects(:createHttpSpan).with do |action, url, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    get "/no/controller/here"

    assert_equal "/no/controller/here", test_action
    assert_equal "http://example.org", test_url
    assert_equal 404, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end

  def test_does_not_send_http_span_for_static_assets
    TraceView::Span.expects(:createHttpSpan).never

    get "/assets/static_asset.png"
  end
end

