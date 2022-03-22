# Copyright (c) SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/minitest'

  class CurbMockedTest < Minitest::Test

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

    def test_API_xtrace_tracing
      stub_request(:get, "http://127.0.0.9:8101/").to_return(status: 200, body: "", headers: {})

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        ::Curl.get("http://127.0.0.9:8101/")
      end

      assert_requested(:get, "http://127.0.0.9:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, true)
      end
      refute SolarWindsAPM::Context.isValid
    end

    def test_API_xtrace_sample_rate_0
      stub_request(:get, "http://127.0.0.4:8101/").to_return(status: 200, body: "", headers: {})

      SolarWindsAPM.config_lock.synchronize do
        SolarWindsAPM::Config[:sample_rate] = 0
        SolarWindsAPM::SDK.start_trace('curb_tests') do
          ::Curl.get("http://127.0.0.4:8101/")
        end
      end

      assert_requested(:get, "http://127.0.0.4:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, false)
      end
      refute SolarWindsAPM::Context.isValid
    end

    # TODO NH-2303 add test case with incoming trace headers
    #  when we are not tracing those headers have to be preserved
    def test_API_xtrace_no_trace
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      ::Curl.get("http://127.0.0.6:8101/")

      assert_requested(:get, "http://127.0.0.6:8101/", times: 1) do |req|
        refute req.headers.transform_keys(&:downcase)['traceparent']
        refute req.headers.transform_keys(&:downcase)['tracestate']
      end
    end

    # TODO NH-2303 add test case with incoming trace headers
    #  when we are not tracing those headers have to be preserved
    def test_multi_get_no_trace
      WebMock.disable!

      Curl::Multi.expects(:http_without_sw_apm).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          refute conf[:headers] && conf[:headers].transform_keys(&:downcase)['traceparent']
          refute conf[:headers].transform_keys(&:downcase)['tracestate']
        end
      end

      easy_options = { :follow_location => true }
      multi_options = { :pipeline => false }

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      Curl::Multi.get(urls, easy_options, multi_options)
      refute SolarWindsAPM::Context.isValid
    end

    def test_multi_get_tracing
      WebMock.disable!

      Curl::Multi.expects(:http_without_sw_apm).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          headers = conf[:headers] || {}
          assert_trace_headers(headers, true)
          assert headers['Custom']
          assert_match /specialvalue/, headers['Custom']
        end
        # true
      end

      easy_options = { :follow_location => true, :headers => { 'Custom' => 'specialvalue' } }
      multi_options = { :pipeline => false }

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        Curl::Multi.get(urls, easy_options, multi_options)
      end
      refute SolarWindsAPM::Context.isValid
    end

    def test_multi_get_tracing_not_sampling
      WebMock.disable!

      Curl::Multi.expects(:http_without_sw_apm).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          headers = conf[:headers] || {}
          assert_trace_headers(headers, false)
          refute sampled?(headers['traceparent'])
        end
        # true
      end

      easy_options = { :follow_location => true }
      multi_options = { :pipeline => false }

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      SolarWindsAPM.config_lock.synchronize do
        SolarWindsAPM::Config[:sample_rate] = 0
        SolarWindsAPM::SDK.start_trace('curb_tests') do
          Curl::Multi.get(urls, easy_options, multi_options)
        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    # TODO NH-2303 add test case with incoming trace headers
    #  when we are not tracing those headers have to be preserved
    def test_multi_perform_no_trace
      WebMock.disable!

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      m = Curl::Multi.new
      urls.each do |url|
        cu = Curl::Easy.new(url) do |curl|
          curl.follow_location = true
        end
        m.add cu
      end

      m.perform do
        m.requests.each do |request|
          request = request[1] if request.is_a?(Array)
          refute request.headers && request.headers['traceparent']
          refute request.headers['tracestate']
        end
      end
    end

    def test_multi_perform_tracing
      WebMock.disable!

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        m = Curl::Multi.new
        urls.each do |url|
          cu = Curl::Easy.new(url) do |curl|
            curl.follow_location = true
            curl.headers = { 'Custom' => 'specialvalue' }
          end
          m.add cu
        end

        m.perform do
          m.requests.each do |request|
            request = request[1] if request.is_a?(Array)
            assert request.headers['Custom']
            assert_trace_headers(request.headers)
          end
        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    def test_multi_perform_tracing_not_sampling
      WebMock.disable!

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      SolarWindsAPM.config_lock.synchronize do
        SolarWindsAPM::Config[:sample_rate] = 0
        SolarWindsAPM::SDK.start_trace('curb_tests') do
          m = Curl::Multi.new
          urls.each do |url|
            cu = Curl::Easy.new(url) do |curl|
              curl.follow_location = true
            end
            m.add cu
          end

          m.perform do
            m.requests.each do |request|
              request = request[1] if request.is_a?(Array)
              assert_trace_headers(request.headers, false)
            end
          end
        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    # preserve custom headers
    #
    # this calls Curl::Easy.http
    def test_Easy_preserves_custom_headers_on_get
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        Curl.get("http://127.0.0.6:8101/") do |curl|
          curl.headers = { 'Custom' => 'specialvalue' }
        end
      end

      assert_requested :get, "http://127.0.0.6:8101/", headers: { 'Custom' => 'specialvalue' }, times: 1
      assert_requested(:get, "http://127.0.0.6:8101/") do |req|
        assert_trace_headers(req.headers)
        assert_equal 'specialvalue', req.headers['Custom']
      end

      refute SolarWindsAPM::Context.isValid
    end

    def test_API_curl_post
      stub_request(:post, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        Curl.post("http://127.0.0.6:8101/")
      end

      assert_requested(:post, "http://127.0.0.6:8101/") do |req|
        assert_trace_headers(req.headers)
      end
    end

    # The following tests can't use WebMock because it interferes with our instrumentation
    def test_preserves_custom_headers_on_http_put
      WebMock.disable!
      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        curl.http_put nil
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']

      assert_trace_headers(curl.headers)

      refute SolarWindsAPM::Context.isValid
    end

    def test_preserves_custom_headers_on_http_post
      WebMock.disable!

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        curl.http_post
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']
      assert_trace_headers(curl.headers, true)

      refute SolarWindsAPM::Context.isValid
    end

    def test_preserves_custom_headers_on_perform
      WebMock.disable!

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      SolarWindsAPM::SDK.start_trace('curb_tests') do
        curl.perform
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']
      assert_trace_headers(curl.headers, true)

      refute SolarWindsAPM::Context.isValid
    end

    ##### W3C tracestate propagation

    def test_w3c_propagation_simple_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc-01'
      headers = { traceparent: trace_id, tracestate: state}

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      SolarWindsAPM::SDK.start_trace('curb_tests', headers: headers) do
        curl.perform
      end

      assert_trace_headers(curl.headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(curl.headers['traceparent'])
      refute_equal state, curl.headers['tracestate']

      refute SolarWindsAPM::Context.isValid
    end

    def test_w3c_propagation_simple_trace_state_not_tracing
      WebMock.disable!
      SolarWindsAPM::Config[:tracing_mode] = :disabled

      trace_id = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1234'
      headers = { traceparent: trace_id, tracestate: state }
      SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.perform

      assert_equal trace_id, curl.headers['traceparent']
      assert_equal state, curl.headers['tracestate']

      refute SolarWindsAPM::Context.isValid
    end

    def test_w3c_propagation_multimember_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      headers = { traceparent: trace_id, tracestate: state }

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      SolarWindsAPM::SDK.start_trace('curb_tests', headers: headers) do
        curl.perform
      end

      assert_trace_headers(curl.headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(curl.headers['traceparent'])
      assert_equal "sw=#{SolarWindsAPM::TraceString.span_id_flags(curl.headers['traceparent'])},aa= 1234,%%cc=%%%45",
                   curl.headers['tracestate']

      refute SolarWindsAPM::Context.isValid
    end

    def test_multi_perform_w3c_propagation_not_tracing
      WebMock.disable!
      SolarWindsAPM::Config[:tracing_mode] = :disabled

      trace_id = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1234'
      headers = { traceparent: trace_id, tracestate: state }
      SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      m = Curl::Multi.new
      urls.each do |url|
        cu = Curl::Easy.new(url) do |curl|
          curl.follow_location = true
        end
        m.add cu
      end

      m.perform do
        m.requests.each do |request|
          request = request[1] if request.is_a?(Array)
          assert_equal trace_id, request.headers['traceparent']
          assert_equal state, request.headers['tracestate']
        end
      end
    end
  end
end

