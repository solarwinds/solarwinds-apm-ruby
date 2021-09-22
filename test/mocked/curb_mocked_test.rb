# Copyright (c) SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/minitest'

  class CurbMockedTest < Minitest::Test

    def setup
      AppOpticsAPM::Context.clear

      WebMock.enable!
      WebMock.reset!
      WebMock.disable_net_connect!

      @sample_rate = AppOpticsAPM::Config[:sample_rate]
      @tracing_mode = AppOpticsAPM::Config[:tracing_mode]
      @blacklist = AppOpticsAPM::Config[:blacklist]

      AppOpticsAPM::Config[:sample_rate] = 1000000
      AppOpticsAPM::Config[:tracing_mode] = :enabled
      AppOpticsAPM::Config[:blacklist] = []
    end

    def teardown
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:tracing_mode] = @tracing_mode
      AppOpticsAPM::Config[:blacklist] = @blacklist
    end

    def test_API_xtrace_tracing
      stub_request(:get, "http://127.0.0.9:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('curb_tests') do
        ::Curl.get("http://127.0.0.9:8101/")
      end

      assert_requested(:get, "http://127.0.0.9:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, true)
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_API_xtrace_sample_rate_0
      stub_request(:get, "http://127.0.0.4:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('curb_tests') do
          ::Curl.get("http://127.0.0.4:8101/")
        end
      end

      assert_requested(:get, "http://127.0.0.4:8101/", times: 1) do |req|
        assert_trace_headers(req.headers, false)
      end
      refute AppOpticsAPM::Context.isValid
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

    def test_API_blacklisted
      stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.2'
        AppOpticsAPM::API.start_trace('curb_test') do
          ::Curl.get("http://127.0.0.2:8101/")
        end
      end

      # TODO NH-2303 wait for final decision, but it is probably
      #  correct to not add trace headers to denylisted hosts
      assert_requested(:get, "http://127.0.0.2:8101/", times: 1) do |req|
        refute req.headers.transform_keys(&:downcase)['traceparent']
        refute req.headers.transform_keys(&:downcase)['tracestate']
      end
      refute AppOpticsAPM::Context.isValid
    end

    # TODO NH-2303 add test case with incoming trace headers
    #  when we are not tracing those headers have to be preserved
    def test_multi_get_no_trace
      WebMock.disable!

      Curl::Multi.expects(:http_without_appoptics).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          refute conf[:headers] && conf[:headers].transform_keys(&:downcase)['traceparent']
          refute conf[:headers].transform_keys(&:downcase)['tracestate']
        end
      end

      easy_options = {:follow_location => true}
      multi_options = {:pipeline => false}

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      Curl::Multi.get(urls, easy_options, multi_options)
      refute AppOpticsAPM::Context.isValid
    end

    def test_multi_get_tracing
      WebMock.disable!

      Curl::Multi.expects(:http_without_appoptics).with do |url_confs, _multi_options|
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

      AppOpticsAPM::API.start_trace('curb_tests') do
        Curl::Multi.get(urls, easy_options, multi_options)
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_multi_get_tracing_not_sampling
      WebMock.disable!

      Curl::Multi.expects(:http_without_appoptics).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          headers = conf[:headers] || {}
          assert_trace_headers(headers, false)
          refute sampled?(headersdd['traceparent'])
        end
        # true
      end

      easy_options = {:follow_location => true}
      multi_options = {:pipeline => false}

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('curb_tests') do
          Curl::Multi.get(urls, easy_options, multi_options)
        end
      end
      refute AppOpticsAPM::Context.isValid
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

      AppOpticsAPM::API.start_trace('curb_tests') do
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
      refute AppOpticsAPM::Context.isValid
    end

    def test_multi_perform_tracing_not_sampling
      WebMock.disable!

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('curb_tests') do
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
      refute AppOpticsAPM::Context.isValid
    end

    # preserve custom headers
    #
    # this calls Curl::Easy.http
    def test_Easy_preserves_custom_headers_on_get
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('curb_tests') do
        Curl.get("http://127.0.0.6:8101/") do |curl|
          curl.headers = { 'Custom' => 'specialvalue' }
        end
      end

      assert_requested :get, "http://127.0.0.6:8101/", headers: {'Custom'=>'specialvalue'}, times: 1
      assert_requested(:get, "http://127.0.0.6:8101/") do |req|
        assert_trace_headers(req.headers)
        assert_equal 'specialvalue', req.headers['Custom']
      end

      refute AppOpticsAPM::Context.isValid
    end

    def test_API_curl_post
      stub_request(:post, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('curb_tests') do
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

      AppOpticsAPM::API.start_trace('curb_tests') do
        curl.http_put nil
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']

      assert_trace_headers(curl.headers)

      refute AppOpticsAPM::Context.isValid
    end

    def test_preserves_custom_headers_on_http_post
      WebMock.disable!

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      AppOpticsAPM::API.start_trace('curb_tests') do
        curl.http_post
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']
      assert_trace_headers(curl.headers, true)

      refute AppOpticsAPM::Context.isValid
    end

    def test_preserves_custom_headers_on_perform
      WebMock.disable!

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      AppOpticsAPM::API.start_trace('curb_tests') do
        curl.perform
      end

      assert curl.headers
      assert curl.headers['Custom']
      assert_match /specialvalue4/, curl.headers['Custom']
      assert_trace_headers(curl.headers, true)

      refute AppOpticsAPM::Context.isValid
    end

  end
end

