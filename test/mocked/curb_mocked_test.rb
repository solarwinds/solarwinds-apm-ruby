# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This test suite focuses on the per-request-xtrace feature
# It tests that we add an x-trace to each outbound request,
# unless TraceView::Config[:curb][:cross_host] is false or the url is blacklisted

# missing tests:
# test the xtrace tracing flag when tracing is true set by an incoming tracing context
# test the correctness of the edges for various scenarios

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/mini_test'
  require 'traceview/inst/rack'

  class CurbTest < Minitest::Test
    include Rack::Test::Methods

    def setup
      WebMock.enable!
      WebMock.disable_net_connect!
      clear_all_traces
      TraceView.config_lock.synchronize {
        @tm = TraceView::Config[:tracing_mode]
        @cross_host = TraceView::Config[:curb][:cross_host]
        @blacklist = TraceView::Config[:blacklist]
      }
    end

    def teardown
      TraceView.config_lock.synchronize {
        TraceView::Config[:tracing_mode] = @tm
        TraceView::Config[:curb][:cross_host] = @cross_host
        TraceView::Config[:blacklist] = @blacklist
      }
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
    end

    def test_xtrace_when_not_tracing
      stub_request(:get, "http://127.0.0.6:8101/").to_return(status: 200, body: "", headers: {})

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        ::Curl.get("http://127.0.0.6:8101/")
      end

      assert_requested :get, "http://127.0.0.6:8101/", times: 1
      assert_requested :get, "http://127.0.0.6:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.6:8101/", headers: {'X-Trace'=>/^2B0*00$/}

    end

    def test_xtrace_when_sample_rate_0
      stub_request(:get, "http://127.0.0.4:8101/").to_return(status: 200, body: "", headers: {})

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        TraceView::Config[:sample_rate] = 1
        ::Curl.get("http://127.0.0.4:8101/")
      end

      assert_requested :get, "http://127.0.0.4:8101/", times: 1
      assert_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B0*00$/}

    end

    def test_xtrace_non_tracing_context
      stub_request(:get, "http://127.0.0.5:8101/").to_return(status: 200, body: "", headers: {})
      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        TraceView::Config[:tracing_mode] = :never
        TraceView::API.start_trace('curb_test') do
          ::Curl.get("http://127.0.0.5:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.5:8101/", times: 1
      assert_requested :get, "http://127.0.0.5:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.5:8101/", headers: {'X-Trace'=>/^2B0*00$/}
    end

    def test_blacklisted
      stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        TraceView::Config.blacklist << '127.0.0.2'
        TraceView::API.start_trace('curb_test') do
          ::Curl.get("http://127.0.0.2:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.2:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*/}, times: 1
    end

    def test_cross_host_false
      stub_request(:get, "http://127.0.0.3:8101/").to_return(status: 200, body: "", headers: {})

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = false
        TraceView::API.start_trace('curb_test') do
          ::Curl.get("http://127.0.0.3:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.3:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*/}, times: 1
    end

    def test_multi_get
      WebMock.disable!

      Curl::Multi.expects(:http_without_traceview).with do |url_confs, _multi_options|
        assert_equal 3, url_confs.size
        url_confs.each do |conf|
          headers = conf[:headers] || {}
          assert headers['X-Trace']
          assert_match /^2B[0-9,A-F]*00$/, headers['X-Trace']
          refute_match /^2B0*00$/, headers['X-Trace']
          # return false if headers['X-Trace'].nil? || headers['X-Trace'] !~ /^2B[0-9,A-F]*00$/
        end
        true
      end

      easy_options = {:follow_location => true}
      multi_options = {:pipeline => false}

      urls = []
      urls << "http://127.0.0.7:8101/?one=1"
      urls << "http://127.0.0.7:8101/?two=2"
      urls << "http://127.0.0.7:8101/?three=3"

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        Curl::Multi.get(urls, easy_options, multi_options)
      end
    end

    def test_multi_perform
      WebMock.disable!
      responses = {}

      urls = []
      urls << "http://127.0.0.1:8101/?one=1"
      urls << "http://127.0.0.1:8101/?two=2"
      urls << "http://127.0.0.1:8101/?three=3"

      TraceView.config_lock.synchronize do
        TraceView::Config[:curb][:cross_host] = true
        m = Curl::Multi.new
        urls.each do |url|
          responses[url] = ""
          cu = Curl::Easy.new(url) do |curl|
            curl.follow_location = true
          end
          m.add cu
        end

        m.perform do
          m.requests.each do |request|
            assert request.headers['X-Trace']
            assert_match /^2B[0-9,A-F]*00$/, request.headers['X-Trace']
            refute_match /^2B0*00$/, request.headers['X-Trace']
          end
        end
      end
    end

  end
end

