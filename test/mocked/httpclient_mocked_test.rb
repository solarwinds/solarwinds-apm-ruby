# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock/minitest'
require 'mocha/minitest'

require 'rack/test'
require 'rack/lobster'
require 'solarwinds_apm/inst/rack'

class HTTPClientMockedTest < Minitest::Test

  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      # use Rack::CommonLogger
      # use Rack::ShowExceptions
      use SolarWindsAPM::Rack
      map "/out" do
        run Proc.new {
          clnt = HTTPClient.new
          clnt.get('http://127.0.0.1:8101/')
          [200, { "Content-Type" => "text/html" }, ['Hello SolarWindsAPM!']]
        }
      end
    }
  end

  def setup
    WebMock.enable!
    WebMock.reset!
    WebMock.disable_net_connect!

    @sample_rate = SolarWindsAPM::Config[:sample_rate]
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]

    SolarWindsAPM::Config[:sample_rate] = 1000000
    SolarWindsAPM::Config[:tracing_mode] = :enabled

    SolarWindsAPM.trace_context = nil
    SolarWindsAPM::Context.clear
  end

  def teardown
    SolarWindsAPM::Config[:sample_rate] = @sample_rate
    SolarWindsAPM::Config[:tracing_mode] = @tracing_mode
  end

  #====== DO REQUEST ===================================================

  def test_do_request_tracing_sampling_array_headers
    stub_request(:get, "http://127.0.0.1:8101/")
    SolarWindsAPM::SDK.start_trace('httpclient_test') do
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.1:8101/', nil, [['some_header', 'some_value'], ['some_header2', 'some_value2']])
    end

    assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, true)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_do_request_tracing_sampling_hash_headers
    stub_request(:get, "http://127.0.0.6:8101/")
    SolarWindsAPM::SDK.start_trace('httpclient_test') do
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.6:8101/', nil, { 'some_header' => 'some_value', 'some_header2' => 'some_value2' })
    end

    assert_requested(:get, "http://127.0.0.6:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, true)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_do_request_tracing_not_sampling
    stub_request(:get, "http://127.0.0.2:8101/")
    SolarWindsAPM.config_lock.synchronize do
      SolarWindsAPM::Config[:sample_rate] = 0
      SolarWindsAPM::SDK.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get('http://127.0.0.2:8101/')
      end
    end

    assert_requested(:get, "http://127.0.0.2:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, false)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_do_request_no_xtrace
    stub_request(:get, "http://127.0.0.3:8101/")
    clnt = HTTPClient.new
    clnt.get('http://127.0.0.3:8101/')

    assert_requested :get, "http://127.0.0.3:8101/", times: 1
    assert_not_requested :get, "http://127.0.0.3:8101/", headers: { 'Traceparent' => /^.*$/ }
  end

  #====== ASYNC REQUEST ================================================
  # using expectations in these tests because stubbing doesn't work with threads

  def test_async_tracing_sampling_array_headers
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_equal 'http://127.0.0.11:8101/', req.header.request_uri.to_s
      assert_trace_headers(req.headers, true)
    end

    SolarWindsAPM::SDK.start_trace('httpclient_test') do
      clnt = HTTPClient.new
      clnt.get_async('http://127.0.0.11:8101/', nil, [['some_header', 'some_value'], ['some_header2', 'some_value2']])
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_async_tracing_sampling_hash_headers
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_equal 'http://127.0.0.16:8101/', req.header.request_uri.to_s
      assert_trace_headers(req.headers, true)
    end

    SolarWindsAPM::SDK.start_trace('httpclient_test') do
      clnt = HTTPClient.new
      clnt.get_async('http://127.0.0.16:8101/', nil, { 'some_header' => 'some_value', 'some_header2' => 'some_value2' })
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_async_tracing_not_sampling
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_equal 'http://127.0.0.12:8101/', req.header.request_uri.to_s
      assert_trace_headers(req.headers, false)
    end

    SolarWindsAPM.config_lock.synchronize do
      SolarWindsAPM::Config[:sample_rate] = 0
      SolarWindsAPM::SDK.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get_async('http://127.0.0.12:8101/')
      end
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_async_no_xtrace
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_equal 'http://127.0.0.13:8101/', req.header.request_uri.to_s
      assert req.header['Traceparent'].empty?
    end

    clnt = HTTPClient.new
    clnt.get_async('http://127.0.0.13:8101/')
  end

  # ========== make sure headers are preserved =============================
  def test_preserves_custom_headers
    stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.6:8101/', nil, [['Custom', 'specialvalue'], ['some_header2', 'some_value2']])
    end

    assert_requested :get, "http://127.0.0.6:8101/", headers: { 'Custom' => 'specialvalue' }, times: 1
    refute SolarWindsAPM::Context.isValid
  end

  def test_async_preserves_custom_headers
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert req.headers['Custom'], "Custom header missing"
      assert_match(/^specialvalue$/, req.headers['Custom'])
    end

    SolarWindsAPM::SDK.start_trace('httpclient_tests') do
      clnt = HTTPClient.new
      clnt.get_async('http://127.0.0.6:8101/', nil, [['Custom', 'specialvalue'], ['some_header2', 'some_value2']])
    end
    refute SolarWindsAPM::Context.isValid
  end

  ##### W3C tracestate propagation

  def test_propagation_simple_trace_state
    stub_request(:get, "http://127.0.0.1:8101/").to_return(status: 200, body: "", headers: {})

    task_id = 'a462ade6cfe479081764cc476aa9831b'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'sw=cb3468da6f06eefc-01'
    headers = { traceparent: trace_id, tracestate: state }

    SolarWindsAPM::SDK.start_trace('httpclient_tests', headers: headers) do
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.1:8101/')
    end

    assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(req.headers['Traceparent'])
      refute_equal state, req.headers['Tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_simple_trace_state_no_tracing
    stub_request(:get, "http://127.0.0.1:8101/").to_return(status: 200, body: "", headers: {})

    task_id = 'a462ade6cfe479081764cc476aa9831b'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'sw=cb3468da6f06eefc-01'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    clnt = HTTPClient.new
    clnt.get('http://127.0.0.1:8101/')

    assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
      assert_equal trace_id, req.headers['Traceparent']
      assert_equal state, req.headers['Tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_w3c_context_propagation_async
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    task_id = 'a462ade6cfe479081764cc476aa9831b'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_trace_headers(req.headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(req.headers['traceparent'])
    end

    SolarWindsAPM::SDK.start_trace('httpclient_tests', headers: headers) do
      clnt = HTTPClient.new
      clnt.get_async('http://127.0.0.1:8101/')
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_w3c_context_propagation_async_no_tracing
    WebMock.disable!

    Thread.expects(:new).yields # continue without forking off a thread

    task_id = 'a462ade6cfe479081764cc476aa9831b'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    HTTPClient.any_instance.expects(:do_get_stream).with do |req, _, _|
      assert_equal trace_id, req.headers['traceparent']
      assert_equal state, req.headers['tracestate']
    end

    clnt = HTTPClient.new
    clnt.get_async('http://127.0.0.1:8101/')

    refute SolarWindsAPM::Context.isValid
  end

end
