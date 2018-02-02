# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/mini_test'
  WebMock.allow_net_connect!

  class CurbMockedTest < Minitest::Test

    def setup
      AppOpticsAPM::Context.clear
      WebMock.enable!
      WebMock.disable_net_connect!
      AppOpticsAPM.config_lock.synchronize {
        @tm = AppOpticsAPM::Config[:tracing_mode]
        @sample_rate = AppOpticsAPM::Config[:sample_rate]
      }
    end

    def teardown
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:tracing_mode] = @tm
        AppOpticsAPM::Config[:blacklist] = []
        AppOpticsAPM::Config[:sample_rate] = @sample_rate
      }
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
    end

    def test_xtrace_tracing
      stub_request(:get, "http://127.0.0.9:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('curb_tests') do
        ::Curl.get("http://127.0.0.9:8101/")
      end

      assert_requested :get, "http://127.0.0.9:8101/", times: 1
      assert_requested :get, "http://127.0.0.9:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*01$/}, times: 1
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_sample_rate_0
      stub_request(:get, "http://127.0.0.4:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('curb_tests') do
          ::Curl.get("http://127.0.0.4:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.4:8101/", times: 1
      assert_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B0*$/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_no_trace
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      ::Curl.get("http://127.0.0.6:8101/")

      assert_requested :get, "http://127.0.0.6:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.6:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    def test_blacklisted
      stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.2'
        AppOpticsAPM::API.start_trace('curb_test') do
          ::Curl.get("http://127.0.0.2:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.2:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^.*/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_multi_get_no_trace
      WebMock.disable!

      Curl::Multi.expects(:http_without_appoptics).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          refute conf[:headers] && conf[:headers]['X-Trace']
        end
        true
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
          assert headers['X-Trace']
          assert headers['Custom']
          assert_match /specialvalue/, headers['Custom']
          assert sampled?(headers['X-Trace'])
        end
        true
      end

      easy_options = {:follow_location => true, :headers => { 'Custom' => 'specialvalue' }}
      multi_options = {:pipeline => false}

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
          assert headers['X-Trace']
          assert not_sampled?(headers['X-Trace'])
        end
        true
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
          refute request.headers && request.headers['X-Trace']
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
            assert request.headers['X-Trace']
            assert request.headers['Custom']
            assert sampled?(request.headers['X-Trace'])
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
              assert request.headers['X-Trace']
              assert not_sampled?(request.headers['X-Trace'])
              refute_match /^2B0*$/, request.headers['X-Trace']
            end
          end
        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    # preserve custom headers
    #
    # this calls Curl::Easy.http
    def test_preserves_custom_headers_on_get
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('curb_tests') do
        Curl.get("http://127.0.0.6:8101/") do |curl|
          curl.headers = { 'Custom' => 'specialvalue' }
        end
      end

      assert_requested :get, "http://127.0.0.6:8101/", headers: {'Custom'=>'specialvalue'}, times: 1
      refute AppOpticsAPM::Context.isValid
    end

    # The following test can't use WebMock because it interferes with our instrumentation
    def test_preserves_custom_headers_on_http_put
      WebMock.disable!

      curl = Curl::Easy.new("http://127.0.0.1:8101/")
      curl.headers = { 'Custom' => 'specialvalue4' }

      AppOpticsAPM::API.start_trace('curb_tests') do
        curl.http_put nil
      end

      assert curl.headers
      assert curl.headers['X-Trace']
      assert curl.headers['Custom']
      assert_match /^2B[0-9,A-F]*01$/, curl.headers['X-Trace']
      assert_match /specialvalue4/, curl.headers['Custom']
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
      assert curl.headers['X-Trace']
      assert curl.headers['Custom']
      assert_match /^2B[0-9,A-F]*01$/, curl.headers['X-Trace']
      assert_match /specialvalue4/, curl.headers['Custom']
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
      assert curl.headers['X-Trace']
      assert curl.headers['Custom']
      assert_match /^2B[0-9,A-F]*01$/, curl.headers['X-Trace']
      assert_match /specialvalue4/, curl.headers['Custom']
      refute AppOpticsAPM::Context.isValid
    end

  end
end

