# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'traceview/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

class CurbTest < Minitest::Test
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  def test_must_return_xtrace_header
    clear_all_traces
    get "/"
    xtrace = last_response['X-Trace']
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert init_kvs.key?('Ruby.Curb.Version')
    assert_equal init_kvs['Ruby.Curb.Version'], "Curb-#{::Curl::VERSION}"
  end

  def test_class_get_request
    clear_all_traces

    TraceView::API.start_trace('curb_tests') do
      Curl.get('http://127.0.0.1:8101/')
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    validate_outer_layers(traces, "curb_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], "http://127.0.0.1:8101/"
    # FIXME
    # assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'curb'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_cross_app_tracing
    clear_all_traces

    TraceView::API.start_trace('curb_tests') do
      response = ::Curl.get('http://127.0.0.1:8101/?blah=1')
      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    validate_outer_layers(traces, "curb_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], "http://127.0.0.1:8101/?blah=1&"
    # FIXME
    # assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_requests_with_errors
    clear_all_traces

    begin
      TraceView::API.start_trace('curb_tests') do
        Curl.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal traces.count, 5
    validate_outer_layers(traces, "curb_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://asfjalkfjlajfljkaljf/'
    # FIXME
    # assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[2]['Layer'], 'curb'
    assert_equal traces[2]['Label'], 'error'
    assert_equal traces[2]['ErrorClass'], "Curl::Err::HostResolutionError"
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')

    assert_equal traces[3]['Layer'], 'curb'
    assert_equal traces[3]['Label'], 'exit'
  end

  def test_obey_log_args_when_false
    @log_args = TraceView::Config[:curb][:log_args]
    clear_all_traces

    TraceView::Config[:curb][:log_args] = false

    TraceView::API.start_trace('curb_tests') do
      Curl.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    assert_equal traces[1]['RemoteURL'], "http://127.0.0.1:8101/"

    TraceView::Config[:curb][:log_args] = @log_args
  end

  def test_obey_log_args_when_true
    @log_args = TraceView::Config[:curb][:log_args]
    clear_all_traces

    TraceView::Config[:curb][:log_args] = true

    TraceView::API.start_trace('curb_tests') do
      ::Curl.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    assert_equal traces[1]['RemoteURL'], "http://127.0.0.1:8101/?blah=1&"

    TraceView::Config[:curb][:log_args] = @log_args
  end
end

