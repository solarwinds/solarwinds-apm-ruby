# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

class RackTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use AppOpticsAPM::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end

      map "/the_exception" do
        run Proc.new {
          raise StandardError
          [500, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']]
        }

      end
    }
  end

  def setup
    @bt = AppOpticsAPM::Config[:rack][:collect_backtraces]
    @log_args = AppOpticsAPM::Config[:rack][:log_args]
    @sr = AppOpticsAPM::Config[:sample_rate]
    clear_all_traces
  end

  def teardown
    AppOpticsAPM::Config[:rack][:collect_backtraces] = @bt
    AppOpticsAPM::Config[:rack][:log_args] =  @log_args
    AppOpticsAPM::Config[:tracing_mode] = :always
    AppOpticsAPM::Config[:sample_rate] = @sr
  end

  def test_get_the_lobster
    # skip("FIXME: broken on travis only") if ENV['TRAVIS'] == "true"

    get "/lobster"

    traces = get_all_traces
    traces.count.must_equal 2

    validate_outer_layers(traces, 'rack')

    kvs = {}
    kvs["Label"] = "entry"
    kvs["URL"] = "/lobster"
    kvs["HTTP-Host"] = "example.org"
    kvs["Port"] = 80
    kvs["Proto"] = "http"
    kvs["Method"] = "GET"
    kvs["ClientIP"] = "127.0.0.1"
    validate_event_keys(traces[0], kvs)
    assert traces[0].has_key?('SampleRate')
    assert traces[0].has_key?('SampleSource')
    assert traces[0].has_key?('ProcessID')
    assert traces[0].has_key?('ThreadID')
    assert traces[0]['Backtrace']
    assert traces[0]['Backtrace'].size > 0

    kvs.clear
    kvs["Layer"] = "rack"
    kvs["Label"] = "exit"
    kvs['Status'] = 200
    validate_event_keys(traces[1], kvs)

    assert last_response.ok?

    assert last_response['X-Trace']
  end

  def test_must_return_xtrace_header
    get "/lobster"
    xtrace = last_response['X-Trace']
    assert xtrace
    assert AppOpticsAPM::XTrace.valid?(xtrace)
  end

  def test_log_args_when_false
    AppOpticsAPM::Config[:rack][:log_args] = false

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert AppOpticsAPM::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster"
  end

  def test_log_args_when_true
    AppOpticsAPM::Config[:rack][:log_args] = true

    get "/lobster?blah=1"

    traces = get_all_traces

    xtrace = last_response['X-Trace']
    assert xtrace
    assert AppOpticsAPM::XTrace.valid?(xtrace)

    traces[0]['URL'].must_equal "/lobster?blah=1"
  end

  def test_has_header_when_not_tracing
    AppOpticsAPM::Config[:sample_rate] = 0

    get "/lobster?blah=1"

    traces = get_all_traces
    assert_equal(0, traces.size)

    assert last_response['X-Trace'], "X-Trace header is missing"
    assert not_sampled?(last_response['X-Trace']), "X-Trace sampling flag is not '00'"
  end

  def test_sends_path_in_http_span_when_no_controller
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil

    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    get "/no/controller/here"

    assert_nil test_action
    assert_equal "http://example.org/no/controller/here", test_url
    assert_equal 404, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end

  def test_does_not_send_http_span_for_static_assets
    AppOpticsAPM::Span.expects(:createHttpSpan).never

    get "/assets/static_asset.png"
  end

  # the status returned by @app.call(env) is usually an integer, but there are cases where it is a string
  # encountered by this app: https://github.com/librato/api which proxies requests "through to a java service by rack"
  def test_status_can_be_a_string
    Rack::URLMap.any_instance.stubs(:call).returns(["200", {"Content-Length"=>"592"}, "the body"])

    result = get '/lobster'

    assert_equal 200, result.status
  end

  def test_exception
    get '/the_exception'

    traces = get_all_traces

    error_trace = traces.find { |trace| trace['Label'] == 'error' }
    assert_equal 'error', error_trace['Spec']
    assert error_trace.key?('ErrorClass')
    assert error_trace.key?('ErrorMsg')
    assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count
  end

  def test_without_backtrace
    AppOpticsAPM::Config[:rack][:collect_backtraces] = false
    get '/lobster'

    traces = get_all_traces

    refute traces[0]['Backtrace']
  end

end

