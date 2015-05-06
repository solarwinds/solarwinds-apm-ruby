require 'minitest_helper'
require 'oboe/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

class HTTPClientTest < Minitest::Test
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  def test_reports_version_init
    init_kvs = ::Oboe::Util.build_init_report
    assert init_kvs.key?('Ruby.HTTPClient.Version')
    assert_equal init_kvs['Ruby.HTTPClient.Version'], "HTTPClient-#{::HTTPClient::VERSION}"
  end

  def test_get_request
    clear_all_traces

    response = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end

    traces = get_all_traces

    assert_equal traces.count, 7
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'httpclient'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_get_with_header_hash
    clear_all_traces

    response = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', nil, { "SOAPAction" => "HelloWorld" })
    end

    traces = get_all_traces

    assert_equal traces.count, 7
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'httpclient'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_get_with_header_array
    clear_all_traces

    response = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', nil, [["Accept", "text/plain"], ["Accept", "text/html"]])
    end

    traces = get_all_traces

    assert_equal traces.count, 7
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'httpclient'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_post_request
    clear_all_traces

    response = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.post('http://127.0.0.1:8101/')
    end

    traces = get_all_traces

    assert_equal traces.count, 7
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'POST'
    assert traces[1].key?('Backtrace')

    assert_equal traces[5]['Layer'], 'httpclient'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_async_get
    clear_all_traces

    conn = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      conn = clnt.get_async('http://127.0.0.1:8101/?blah=1')
    end

    # sleep for a few to allow async requests to finish
    sleep 3

    traces = get_all_traces
    assert_equal traces.count, 7
    valid_edges?(traces)

    # FIXME: validate_outer_layers assumes that the traces
    # are ordered which in the case of async, they aren't
    # validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[2]['Async'], 1
    assert_equal traces[2]['IsService'], 1
    assert_equal traces[2]['RemoteURL'], 'http://127.0.0.1:8101/?blah=1'
    assert_equal traces[2]['HTTPMethod'], 'GET'
    assert traces[2].key?('Backtrace')

    assert_equal traces[6]['Layer'], 'httpclient'
    assert_equal traces[6]['Label'], 'exit'
    assert_equal traces[6]['HTTPStatus'], 200
  end

  def test_cross_app_tracing
    clear_all_traces

    response = nil

    Oboe::API.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end

    xtrace = response.headers['X-Trace']
    assert xtrace
    assert Oboe::XTrace.valid?(xtrace)

    traces = get_all_traces

    assert_equal traces.count, 7
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[2]['Layer'], 'rack'
    assert_equal traces[2]['Label'], 'entry'
    assert_equal traces[3]['Layer'], 'rack'
    assert_equal traces[3]['Label'], 'info'
    assert_equal traces[4]['Layer'], 'rack'
    assert_equal traces[4]['Label'], 'exit'

    assert_equal traces[5]['Layer'], 'httpclient'
    assert_equal traces[5]['Label'], 'exit'
    assert_equal traces[5]['HTTPStatus'], 200
  end

  def test_requests_with_errors
    clear_all_traces

    result = nil
    begin
      Oboe::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        result = clnt.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal traces.count, 5
    valid_edges?(traces)
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://asfjalkfjlajfljkaljf/'
    assert_equal traces[1]['HTTPMethod'], 'GET'
    assert traces[1].key?('Backtrace')

    assert_equal traces[2]['Layer'], 'httpclient'
    assert_equal traces[2]['Label'], 'error'
    assert_equal traces[2]['ErrorClass'], "SocketError"
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')

    assert_equal traces[3]['Layer'], 'httpclient'
    assert_equal traces[3]['Label'], 'exit'
  end
end

