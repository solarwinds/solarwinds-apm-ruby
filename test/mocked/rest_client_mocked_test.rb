# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock/minitest'
require 'mocha/minitest'

require 'rack/test'
require 'rack/lobster'
require 'solarwinds_apm/inst/rack'

class RestClientMockedTest < Minitest::Test

  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      # use Rack::CommonLogger
      # use Rack::ShowExceptions
      use SolarWindsAPM::Rack
      map "/out" do
        run Proc.new {
          RestClient::Resource.new('http://127.0.0.1:8101').get
          [200, { "Content-Type" => "text/html" }, ['Hello SolarWindsAPM!']]
        }
      end
    }
  end

  def setup
    SolarWindsAPM::Context.clear

    WebMock.enable!
    WebMock.reset!
    WebMock.disable_net_connect!

    @sample_rate = SolarWindsAPM::Config[:sample_rate]
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]

    SolarWindsAPM::Config[:sample_rate] = 1000000
    SolarWindsAPM::Config[:tracing_mode] = :enabled
  end

  def teardown
    SolarWindsAPM::Config[:sample_rate] = @sample_rate
    SolarWindsAPM::Config[:tracing_mode] = @tracing_mode

    SolarWindsAPM.trace_context = nil
  end

  def test_tracing_sampling
    stub_request(:get, "http://127.0.0.1:8101/").to_return(status: 200, body: "", headers: {})

    SolarWindsAPM::SDK.start_trace('rest_client_tests') do
      RestClient::Resource.new('http://127.0.0.1:8101').get
    end

    assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, true)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_tracing_not_sampling
    stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

    SolarWindsAPM.config_lock.synchronize do
      SolarWindsAPM::Config[:sample_rate] = 0
      SolarWindsAPM::SDK.start_trace('rest_client_tests') do
        RestClient::Resource.new('http://127.0.0.2:8101').get
      end
    end

    assert_requested(:get, "http://127.0.0.2:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, false)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_no_xtrace
    stub_request(:get, "http://127.0.0.3:8101/").to_return(status: 200, body: "", headers: {})

    RestClient::Resource.new('http://127.0.0.3:8101').get

    assert_requested :get, "http://127.0.0.3:8101/", times: 1
    assert_not_requested :get, "http://127.0.0.3:8101/", headers: { 'X-Trace' => /^.*$/ }
  end

  def test_preserves_custom_headers
    stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

    SolarWindsAPM::SDK.start_trace('rest_client_tests') do
      RestClient::Resource.new('http://127.0.0.6:8101', headers: { 'Custom' => 'specialvalue' }).get
    end

    assert_requested :get, "http://127.0.0.6:8101/", headers: { 'Custom' => 'specialvalue' }, times: 1
    refute SolarWindsAPM::Context.isValid
  end

  ##### W3C tracestate propagation

  def test_propagation_simple_trace_state
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'sw=cb3468da6f06eefc-01'
    headers = { traceparent: trace_id, tracestate: state }

    SolarWindsAPM::SDK.start_trace('restclient_tests', headers: headers) do
      res = RestClient::Resource.new('http://127.0.0.1:8101').get

      assert_trace_headers(res.request.processed_headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(res.request.processed_headers['traceparent'])
      refute_equal state, res.request.processed_headers['tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_w3c_propagation_simple_trace_state_not_tracing
    WebMock.disable!
    SolarWindsAPM::Config[:tracing_mode] = :disabled

    trace_id = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
    state = 'aa=1234'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    res = RestClient::Resource.new('http://127.0.0.1:8101').get

    assert_equal trace_id, res.request.processed_headers['traceparent']
    assert_equal state, res.request.processed_headers['tracestate']

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_multimember_trace_state
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }

    SolarWindsAPM::SDK.start_trace('restclient_tests', headers: headers) do
      res = RestClient::Resource.new('http://127.0.0.1:8101').get
      assert_trace_headers(res.request.processed_headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(res.request.processed_headers['traceparent'])
      assert_equal "sw=#{SolarWindsAPM::TraceString.span_id_flags(res.request.processed_headers['traceparent'])},aa= 1234,%%cc=%%%45",
                   res.request.processed_headers['tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_multimember_trace_state_no_tracing
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    res = RestClient::Resource.new('http://127.0.0.1:8101').get
    assert_equal trace_id, res.request.processed_headers['traceparent']
    assert_equal state, res.request.processed_headers['tracestate']

    refute SolarWindsAPM::Context.isValid
  end

end
