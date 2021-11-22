# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/minitest'

  require 'rack/test'
  require 'rack/lobster'
  require 'appoptics_apm/inst/rack'

  class RestClientMockedTest < Minitest::Test

    include Rack::Test::Methods

    def app
      @app = Rack::Builder.new {
        # use Rack::CommonLogger
        # use Rack::ShowExceptions
        use AppOpticsAPM::Rack
        map "/out" do
          run Proc.new {
            RestClient::Resource.new('http://127.0.0.1:8101').get
            [200, { "Content-Type" => "text/html" }, ['Hello AppOpticsAPM!']]
          }
        end
      }
    end

    def setup
      AppOpticsAPM::Context.clear

      WebMock.enable!
      WebMock.reset!
      WebMock.disable_net_connect!

      @sample_rate = AppOpticsAPM::Config[:sample_rate]
      @tracing_mode = AppOpticsAPM::Config[:tracing_mode]

      AppOpticsAPM::Config[:sample_rate] = 1000000
      AppOpticsAPM::Config[:tracing_mode] = :enabled
    end

    def teardown
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:tracing_mode] = @tracing_mode

      AppOpticsAPM.trace_context = nil
    end

    def test_tracing_sampling
      stub_request(:get, "http://127.0.0.1:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::SDK.start_trace('rest_client_tests') do
        RestClient::Resource.new('http://127.0.0.1:8101').get
      end

      assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, true)
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_tracing_not_sampling
      stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::SDK.start_trace('rest_client_tests') do
          RestClient::Resource.new('http://127.0.0.2:8101').get
        end
      end

      assert_requested(:get, "http://127.0.0.2:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, false)
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_no_xtrace
      stub_request(:get, "http://127.0.0.3:8101/").to_return(status: 200, body: "", headers: {})

      RestClient::Resource.new('http://127.0.0.3:8101').get

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.3:8101/", headers: { 'X-Trace' => /^.*$/ }
    end

    def test_preserves_custom_headers
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::SDK.start_trace('rest_client_tests') do
        RestClient::Resource.new('http://127.0.0.6:8101', headers: { 'Custom' => 'specialvalue' }).get
      end

      assert_requested :get, "http://127.0.0.6:8101/", headers: { 'Custom' => 'specialvalue' }, times: 1
      refute AppOpticsAPM::Context.isValid
    end

    ##### W3C tracestate propagation

    def test_propagation_simple_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc-01'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      AppOpticsAPM::SDK.start_trace('restclient_tests') do
        res = RestClient::Resource.new('http://127.0.0.1:8101').get

        assert_trace_headers(res.request.processed_headers, true)
        assert_equal task_id, AppOpticsAPM::TraceString.trace_id(res.request.processed_headers['traceparent'])
        refute_equal state, res.request.processed_headers['tracestate']
      end

      refute AppOpticsAPM::Context.isValid
    end

    def test_w3c_propagation_simple_trace_state_not_tracing
      WebMock.disable!
      AppOpticsAPM::Config[:tracing_mode] = :disabled

      trace_id = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1234'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      res = RestClient::Resource.new('http://127.0.0.1:8101').get

      assert_equal trace_id, res.request.processed_headers['traceparent']
      assert_equal state, res.request.processed_headers['tracestate']

      refute AppOpticsAPM::Context.isValid
    end

    def test_propagation_multimember_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      AppOpticsAPM::SDK.start_trace('restclient_tests') do
        res = RestClient::Resource.new('http://127.0.0.1:8101').get
        assert_trace_headers(res.request.processed_headers, true)
        assert_equal task_id, AppOpticsAPM::TraceString.trace_id(res.request.processed_headers['traceparent'])
        assert_equal "sw=#{AppOpticsAPM::TraceString.span_id_flags(res.request.processed_headers['traceparent'])},aa= 1234,%%cc=%%%45",
                     res.request.processed_headers['tracestate']
      end

      refute AppOpticsAPM::Context.isValid
    end

    def test_propagation_multimember_trace_state_no_tracing
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      res = RestClient::Resource.new('http://127.0.0.1:8101').get
      assert_equal trace_id, res.request.processed_headers['traceparent']
      assert_equal state, res.request.processed_headers['tracestate']

      refute AppOpticsAPM::Context.isValid
    end

  end
end
