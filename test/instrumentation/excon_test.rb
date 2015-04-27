require 'minitest_helper'
require 'oboe/inst/rack'
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
    assert Oboe::XTrace.valid?(xtrace)
  end

  def test_reports_version_init
    init_kvs = ::Oboe::Util.build_init_report
    assert init_kvs.key?('Ruby.Excon.Version')
    assert_equal init_kvs['Ruby.Excon.Version'], "Excon-#{::Excon::VERSION}"
  end

  def test_class_get_request
    clear_all_traces

    Oboe::API.start_trace('excon_tests') do
      response = Excon.get('http://127.0.0.1:8101/')
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

    Oboe::API.start_trace('excon_tests') do
      response = Excon.get('http://www.gameface.in/gamers')
      xtrace = response.headers['X-Trace']
      assert xtrace
      assert Oboe::XTrace.valid?(xtrace)
    end

    traces = get_all_traces
    assert_equal traces.count, 4
    validate_outer_layers(traces, "excon_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], 'www.gameface.in'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/gamers'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')
    assert_equal traces[2]['HTTPStatus'], 200
  end

  def test_persistent_requests
    # Persistence was adding in 0.31.0
    skip if Excon::VERSION < '0.31.0'

    clear_all_traces

    Oboe::API.start_trace('excon_tests') do
      connection = Excon.new('http://www.gameface.in/') # non-persistent by default
      connection.get # socket established, then closed
      connection.get(:persistent => true) # socket established, left open
      connection.get # socket reused, then closed
    end

    traces = get_all_traces
    assert_equal traces.count, 8
    validate_outer_layers(traces, "excon_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], 'www.gameface.in'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')
    assert_equal traces[2]['HTTPStatus'], 200

    assert_equal traces[3]['IsService'], 1
    assert_equal traces[3]['RemoteHost'], 'www.gameface.in'
    assert_equal traces[3]['RemoteProtocol'], 'HTTP'
    assert_equal traces[3]['ServiceArg'], '/'
    assert_equal traces[3]['HTTPMethod'], 'GET'
    assert traces[3].key?('Backtrace')
    assert_equal traces[4]['HTTPStatus'], 200

    assert_equal traces[5]['IsService'], 1
    assert_equal traces[5]['RemoteHost'], 'www.gameface.in'
    assert_equal traces[5]['RemoteProtocol'], 'HTTP'
    assert_equal traces[5]['ServiceArg'], '/'
    assert_equal traces[5]['HTTPMethod'], 'GET'
    assert traces[5].key?('Backtrace')
    assert_equal traces[6]['HTTPStatus'], 200
  end

  def test_pipelined_requests
    skip if Excon::VERSION <= '0.17.0'

    clear_all_traces

    Oboe::API.start_trace('excon_tests') do
      connection = Excon.new('http://www.gameface.in/')
      connection.requests([{:method => :get}, {:method => :put}])
    end

    traces = get_all_traces
    assert_equal traces.count, 4
    validate_outer_layers(traces, "excon_tests")
    valid_edges?(traces)

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteHost'], 'www.gameface.in'
    assert_equal traces[1]['RemoteProtocol'], 'HTTP'
    assert_equal traces[1]['ServiceArg'], '/'
    assert_equal traces[1]['Pipeline'], 'true'
    assert_equal traces[1]['HTTPMethods'], 'GET, PUT'
    assert traces[1].key?('Backtrace')
  end

  def test_requests_with_errors
    clear_all_traces

    begin
      Oboe::API.start_trace('excon_tests') do
        connection = Excon.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal traces.count, 5
    validate_outer_layers(traces, "excon_tests")

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
end

