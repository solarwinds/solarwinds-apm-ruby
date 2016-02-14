# Copyright (c) 2015 AppNeta, Inc.
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
    assert xtrace
    assert TraceView::XTrace.valid?(xtrace)
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert init_kvs.key?('Ruby.excon.Version')
    assert_equal init_kvs['Ruby.excon.Version'], ::Excon::VERSION
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

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], '127.0.0.1'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'excon'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
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
    assert_equal traces.count, 7
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], '127.0.0.1'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/?blah=1'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')
    assert_equal traces[5]['HTTPStatus'], 200
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

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], '127.0.0.1'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')
    assert_equal traces[5]['HTTPStatus'], 200

    assert_equal traces[6]['IsService'], 1
    assert_equal traces[6]['RemoteHost'], '127.0.0.1'
    assert_equal traces[6]['RemoteProtocol'], 'HTTP'
    assert_equal traces[6]['ServiceArg'], '/'
    assert_equal traces[6]['HTTPMethod'], 'GET'
    assert traces[6].key?('Backtrace')
    assert_equal traces[10]['HTTPStatus'], 200

    assert_equal traces[11]['IsService'], 1
    assert_equal traces[11]['RemoteHost'], '127.0.0.1'
    assert_equal traces[11]['RemoteProtocol'], 'HTTP'
    assert_equal traces[11]['ServiceArg'], '/'
    assert_equal traces[11]['HTTPMethod'], 'GET'
    assert traces[11].key?('Backtrace')
    assert_equal traces[15]['HTTPStatus'], 200
  end

  def test_pipelined_requests
    skip if Excon::VERSION <= '0.17.0'

    clear_all_traces

    TraceView::API.start_trace('excon_tests') do
      connection = Excon.new('http://127.0.0.1:8101/')
      connection.requests([{:method => :get}, {:method => :put}])
    end

    traces = get_all_traces
    assert_equal traces.count, 10
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], '127.0.0.1'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['Pipeline'], 'true'
    assert_equal traces[1]['HTTPMethods'], 'GET, PUT'
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

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], 'asfjalkfjlajfljkaljf'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[2]['Layer'], 'excon'
    assert_equal traces[2]['Label'], 'error'
    assert_equal traces[2]['ErrorClass'], "Excon::Errors::SocketError"
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')

    assert_equal traces[3]['Layer'], 'excon'
    assert_equal traces[3]['Label'], 'exit'
  end

  def test_obey_log_args_when_false
    @log_args = TraceView::Config[:excon][:log_args]
    clear_all_traces

    TraceView::Config[:excon][:log_args] = false

    TraceView::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal traces.count, 7
    assert_equal traces[1]['ServiceArg'], '/'

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
    assert_equal traces.count, 7
    assert_equal traces[1]['ServiceArg'], '/?blah=1'

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
    assert_equal traces.count, 7
    assert_equal traces[1]['ServiceArg'], '/?blah=1'

    TraceView::Config[:excon][:log_args] = @log_args
  end
end

