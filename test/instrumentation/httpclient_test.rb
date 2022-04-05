# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'solarwinds_apm/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

describe 'HTTPClientTest' do
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  before do
    clear_all_traces
    @tm = SolarWindsAPM::Config[:tracing_mode]
    @sample_rate = SolarWindsAPM::Config[:sample_rate]
    SolarWindsAPM::Config[:tracing_mode] = :enabled
    SolarWindsAPM::Config[:sample_rate] = 1000000

    # TODO remove with NH-11132
    # not a request entry point, context set up in test with start_trace
    SolarWindsAPM::Context.clear
  end

  after do
    SolarWindsAPM::Config[:tracing_mode] = @tm
    SolarWindsAPM::Config[:sample_rate] = @sample_rate
  end

  it 'has SolarWinds instrumentation' do
    assert HTTPClient.ancestors.include?(SolarWindsAPM::Inst::HTTPClient)
  end

  it 'identifies the version' do
    init_kvs = ::SolarWindsAPM::Util.build_init_report
    assert init_kvs.key?('Ruby.httpclient.Version')
    assert_equal ::HTTPClient::VERSION, init_kvs['Ruby.httpclient.Version']
  end

  it 'sends event for a request' do
    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      context = SolarWindsAPM::Context.toString
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })

      # Validate returned tracestring
      assert response.headers.key?("X-Trace")
      assert SolarWindsAPM::TraceString.valid?(response.headers["X-Trace"])
      assert_equal(SolarWindsAPM::TraceString.trace_id(context),
                   SolarWindsAPM::TraceString.trace_id(response.headers["X-Trace"]))
    end

    traces = get_all_traces
    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/?keyword=ruby&lang=en'
    assert_equal traces[1]['HTTPMethod'], 'GET'

    assert_equal traces[4]['Layer'], 'httpclient'
    assert_equal traces[4]['Label'], 'exit'
    assert_equal traces[4]['HTTPStatus'], 200
    assert traces[4].key?('Backtrace')
  end

  it 'works with a request to an uninstrumented app' do
    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8110/', :query => { :keyword => 'ruby', :lang => 'en' })
      refute response.headers.key?("X-Trace")
    end

    traces = get_all_traces
    assert_equal 4, traces.count
    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8110/?keyword=ruby&lang=en'
    assert_equal traces[1]['HTTPMethod'], 'GET'

    assert_equal traces[2]['Layer'], 'httpclient'
    assert_equal traces[2]['Label'], 'exit'
    assert_equal traces[2]['HTTPStatus'], 200
    assert traces[2].key?('Backtrace')
  end

  it 'works with a header hash' do
    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', nil, { "SOAPAction" => "HelloWorld" })
    end

    traces = get_all_traces
    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'

    assert_equal traces[4]['Layer'], 'httpclient'
    assert_equal traces[4]['Label'], 'exit'
    assert_equal traces[4]['HTTPStatus'], 200
    assert traces[4].key?('Backtrace')
  end

  it 'works with a header array' do
    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', nil, [["Accept", "text/plain"], ["Accept", "text/html"]])
    end

    traces = get_all_traces

    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'GET'

    assert_equal traces[4]['Layer'], 'httpclient'
    assert_equal traces[4]['Label'], 'exit'
    assert_equal traces[4]['HTTPStatus'], 200
    assert traces[4].key?('Backtrace')
  end

  it 'works for a post request' do
    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.post('http://127.0.0.1:8101/')
    end

    traces = get_all_traces

    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal traces[1]['IsService'], 1
    assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
    assert_equal traces[1]['HTTPMethod'], 'POST'

    assert_equal traces[4]['Layer'], 'httpclient'
    assert_equal traces[4]['Label'], 'exit'
    assert_equal traces[4]['HTTPStatus'], 200
    assert traces[4].key?('Backtrace')
  end

  it 'works with an async get' do
    conn = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      conn = clnt.get_async('http://127.0.0.1:8101/?blah=1')
    end

    # Allow async request to finish
    Thread.pass until conn.finished?

    traces = get_all_traces
    print_traces traces

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"

    # In the case of async the layers are not always ordered the same
    # validate_outer_layers is not applicable, so we make sure we get the pair for 'httpclient_tests'
    assert_equal 2, traces.select { |trace| trace['Layer'] == 'httpclient_tests' }.size

    # because of possible different ordering of traces we can't rely on an index and need to use find
    async_entry = traces.find { |trace| trace['Layer'] == 'httpclient' && trace['Label'] == 'entry' }
    assert_equal 'rsc', async_entry['Spec']
    assert_equal 1, async_entry['Async']
    assert_equal 1, async_entry['IsService']
    assert_equal 'http://127.0.0.1:8101/?blah=1', async_entry['RemoteURL']
    assert_equal 'GET', async_entry['HTTPMethod']

    assert_equal 'httpclient', traces[5]['Layer']
    assert_equal 'exit', traces[5]['Label']
    assert_equal 200, traces[5]['HTTPStatus']
    assert traces[5].key?('Backtrace')
  end

  it 'works for cross app tracing' do
    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end

    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    traces = get_all_traces

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal 1, traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']
    assert_equal 'GET', traces[1]['HTTPMethod']

    assert_equal 'rack', traces[2]['Layer']
    assert_equal 'entry', traces[2]['Label']
    assert_equal 'rack', traces[3]['Layer']
    assert_equal 'exit', traces[3]['Label']

    assert_equal 'httpclient', traces[4]['Layer']
    assert_equal 'exit', traces[4]['Label']
    assert_equal 200, traces[4]['HTTPStatus']
    assert traces[4].key?('Backtrace')
  end

  it 'works when there are errors' do
    result = nil
    begin
      SolarWindsAPM::SDK.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        clnt.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal 5, traces.count
    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, "httpclient_tests")

    assert_equal 'rsc', traces[1]['Spec']
    assert_equal 1, traces[1]['IsService']
    assert_equal 'http://asfjalkfjlajfljkaljf/', traces[1]['RemoteURL']
    assert_equal 'GET', traces[1]['HTTPMethod']

    assert_equal 'httpclient', traces[2]['Layer']
    assert_equal 'error', traces[2]['Spec']
    assert_equal 'error', traces[2]['Label']
    assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

    assert_equal "SocketError", traces[2]['ErrorClass']
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')
    assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

    assert_equal 'httpclient', traces[3]['Layer']
    assert_equal 'exit', traces[3]['Label']
    assert traces[3].key?('Backtrace')
  end

  it 'logs arguments when true' do
    @log_args = SolarWindsAPM::Config[:httpclient][:log_args]
    SolarWindsAPM::Config[:httpclient][:log_args] = true

    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end

    traces = get_all_traces

    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']

    SolarWindsAPM::Config[:httpclient][:log_args] = @log_args
  end

  it 'does not log args when false' do
    @log_args = SolarWindsAPM::Config[:httpclient][:log_args]
    SolarWindsAPM::Config[:httpclient][:log_args] = false

    response = nil

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end

    traces = get_all_traces

    tracestring = response.headers['X-Trace']
    assert tracestring
    assert SolarWindsAPM::TraceString.valid?(tracestring)

    assert_equal 6, traces.count
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']

    SolarWindsAPM::Config[:httpclient][:log_args] = @log_args
  end

  it 'works without tracing context' do
    clnt = HTTPClient.new
    clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })

    traces = get_all_traces
    # we only get traces from rack
    assert_equal 2, traces.count, print_traces(traces)
    traces.each do |trace|
      assert_equal 'rack', trace["Layer"]
    end

  end
end
