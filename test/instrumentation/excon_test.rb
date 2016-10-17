# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'traceview/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

class ExconTest < Minitest::Test
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  def test_must_return_xtrace_header
    clear_all_traces
    get "/"
    xtrace = last_response['X-Trace']
    # FIXME: This test passes inconsistently.  Investigate
    # Rack response header management under JRUBY.
    skip if defined?(JRUBY_VERSION)
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert_equal ::Excon::VERSION, init_kvs['Ruby.excon.Version']
  end

  def test_class_get_request
    clear_all_traces

    TraceView::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/')
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal 1,           traces[1]['IsService']
    assert_equal '127.0.0.1', traces[1]['RemoteHost']
    assert_equal 'HTTP',      traces[1]['RemoteProtocol']
    assert_equal '/',         traces[1]['ServiceArg']
    assert_equal 'GET',       traces[1]['HTTPMethod']
    assert traces[1].key?('Backtrace')

    assert_equal 'excon',     traces[5]['Layer']
    assert_equal 'exit',      traces[5]['Label']
    assert_equal 200,         traces[5]['HTTPStatus']
  end

  def test_cross_app_tracing
    clear_all_traces

    TraceView::API.start_trace('excon_tests') do
      response = Excon.get('http://127.0.0.1:8101/?blah=1')
      xtrace = response.headers['X-Trace']

      unless defined?(JRUBY_VERSION)
        # FIXME: Works on live stacks; fails in tests
        assert xtrace
        assert TraceView::XTrace.valid?(xtrace)
      end
    end

    traces = get_all_traces
    assert_equal 7, traces.count
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal 1,            traces[1]['IsService']
    assert_equal '127.0.0.1',  traces[1]['RemoteHost']
    assert_equal 'HTTP',       traces[1]['RemoteProtocol']
    assert_equal '/?blah=1',   traces[1]['ServiceArg']
    assert_equal 'GET',        traces[1]['HTTPMethod']
    assert_equal 200,          traces[5]['HTTPStatus']
    assert traces[1].key?('Backtrace')
  end

  def test_persistent_requests
    # Persistence was adding in 0.31.0
    skip if Excon::VERSION < '0.31.0'

    clear_all_traces

    TraceView::API.start_trace('excon_tests') do
      connection = Excon.new('http://127.0.0.1:8101/') # non-persistent by default
      connection.get # socket established, then closed
      connection.get(:persistent => true) # socket established, left open
      connection.get # socket reused, then closed
    end

    traces = get_all_traces
    assert_equal traces.count, 17
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal 1,             traces[1]['IsService']
    assert_equal '127.0.0.1',   traces[1]['RemoteHost']
    assert_equal 'HTTP',        traces[1]['RemoteProtocol']
    assert_equal '/',           traces[1]['ServiceArg']
    assert_equal 'GET',         traces[1]['HTTPMethod']
    assert_equal 200,           traces[5]['HTTPStatus']
    assert traces[1].key?('Backtrace')

    assert_equal 1,             traces[6]['IsService']
    assert_equal '127.0.0.1',   traces[6]['RemoteHost']
    assert_equal 'HTTP',        traces[6]['RemoteProtocol']
    assert_equal '/',           traces[6]['ServiceArg']
    assert_equal 'GET',         traces[6]['HTTPMethod']
    assert_equal 200,           traces[10]['HTTPStatus']
    assert traces[6].key?('Backtrace')

    assert_equal 1,             traces[11]['IsService']
    assert_equal '127.0.0.1',   traces[11]['RemoteHost']
    assert_equal 'HTTP',        traces[11]['RemoteProtocol']
    assert_equal '/',           traces[11]['ServiceArg']
    assert_equal 'GET',         traces[11]['HTTPMethod']
    assert_equal 200,           traces[15]['HTTPStatus']
    assert traces[11].key?('Backtrace')
  end

  def test_pipelined_requests
    skip if Excon::VERSION <= '0.17.0'

    clear_all_traces

    TraceView::API.start_trace('excon_tests') do
      connection = Excon.new('http://127.0.0.1:8101/')
      connection.requests([{:method => :get}, {:method => :put}])
    end

    traces = get_all_traces
    assert_equal 10, traces.count
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal 1,             traces[1]['IsService']
    assert_equal '127.0.0.1',   traces[1]['RemoteHost']
    assert_equal 'HTTP',        traces[1]['RemoteProtocol']
    assert_equal '/',           traces[1]['ServiceArg']
    assert_equal 'true',        traces[1]['Pipeline']
    assert_equal 'GET, PUT',    traces[1]['HTTPMethods']
    assert traces[1].key?('Backtrace')
  end

  def test_requests_with_errors
    clear_all_traces

    begin
      TraceView::API.start_trace('excon_tests') do
        Excon.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal traces.count, 5
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal 1,                          traces[1]['IsService']
    assert_equal 'asfjalkfjlajfljkaljf',     traces[1]['RemoteHost']
    assert_equal 'HTTP',                     traces[1]['RemoteProtocol']
    assert_equal '/',                        traces[1]['ServiceArg']
    assert_equal 'GET',                      traces[1]['HTTPMethod']
    assert traces[1].key?('Backtrace')

    assert_equal 'excon',                    traces[2]['Layer']
    assert_equal 'error',                    traces[2]['Label']
    assert_equal "Excon::Error::Socket",     traces[2]['ErrorClass']
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')

    assert_equal 'excon',                    traces[3]['Layer']
    assert_equal 'exit',                     traces[3]['Label']
  end

  def test_obey_log_args_when_false
    @log_args = TraceView::Config[:excon][:log_args]
    clear_all_traces

    TraceView::Config[:excon][:log_args] = false

    TraceView::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal 7, traces.count
    assert_equal '/', traces[1]['ServiceArg']

    TraceView::Config[:excon][:log_args] = @log_args
  end

  def test_obey_log_args_when_true
    @log_args = TraceView::Config[:excon][:log_args]
    clear_all_traces

    TraceView::Config[:excon][:log_args] = true

    TraceView::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal 7, traces.count
    assert_equal '/?blah=1', traces[1]['ServiceArg']

    TraceView::Config[:excon][:log_args] = @log_args
  end

  def test_obey_log_args_when_true_and_using_hash
    @log_args = TraceView::Config[:excon][:log_args]
    clear_all_traces

    TraceView::Config[:excon][:log_args] = true

    TraceView::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?', :query => { :blah => 1 })
    end

    traces = get_all_traces
    assert_equal 7, traces.count
    assert_equal '/?blah=1', traces[1]['ServiceArg']

    TraceView::Config[:excon][:log_args] = @log_args
  end
end

