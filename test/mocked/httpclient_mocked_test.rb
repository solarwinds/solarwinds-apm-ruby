# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/mini_test'
  WebMock.allow_net_connect!

  class HTTPClientMockedTest < Minitest::Test

    def setup
      WebMock.enable!
      WebMock.disable_net_connect!
      TraceView.config_lock.synchronize do
        @sample_rate = TraceView::Config[:sample_rate]
      end
    end

    def teardown
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = @sample_rate
        TraceView::Config[:blacklist] = []
      end
    end

    #====== DO REQUEST ===================================================

    def test_do_request_tracing_sampling_array_headers
      stub_request(:get, "http://127.0.0.1:8101/")
      TraceView::API.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get('http://127.0.0.1:8101/', nil, [['some_header', 'some_value'], ['some_header2', 'some_value2']])
      end

      assert_requested :get, "http://127.0.0.1:8101/", times: 1
      assert_requested :get, "http://127.0.0.1:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*01$/}, times: 1
    end

    def test_do_request_tracing_sampling_hash_headers
      stub_request(:get, "http://127.0.0.6:8101/")
      TraceView::API.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get('http://127.0.0.6:8101/', nil, { 'some_header' => 'some_value', 'some_header2' => 'some_value2' })
      end

      assert_requested :get, "http://127.0.0.6:8101/", times: 1
      assert_requested :get, "http://127.0.0.6:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*01$/}, times: 1
    end

    def test_do_request_tracing_not_sampling
      stub_request(:get, "http://127.0.0.2:8101/")
      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::API.start_trace('httpclient_test') do
          clnt = HTTPClient.new
          clnt.get('http://127.0.0.2:8101/')
        end
      end

      assert_requested :get, "http://127.0.0.2:8101/", times: 1
      assert_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B0*$/}
    end

    def test_do_request_no_xtrace
      stub_request(:get, "http://127.0.0.3:8101/")
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.3:8101/')

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.3:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    def test_do_request_blacklisted
      stub_request(:get, "http://127.0.0.4:8101/")

      TraceView.config_lock.synchronize do
        TraceView::Config.blacklist << '127.0.0.4'
        TraceView::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          clnt.get('http://127.0.0.4:8101/')
        end
      end

      assert_requested :get, "http://127.0.0.4:8101/"
      assert_not_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    def test_do_request_not_sampling_blacklisted
      stub_request(:get, "http://127.0.0.5:8101/")

      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::Config.blacklist << '127.0.0.5'
        TraceView::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          clnt.get('http://127.0.0.5:8101/')
        end
      end

      assert_requested :get, "http://127.0.0.5:8101/"
      assert_not_requested :get, "http://127.0.0.5:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    #====== ASYNC REQUEST ================================================
    # using expectations in these tests because stubbing doesn't work with threads

    def test_async_tracing_sampling_array_headers
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.11:8101/' == req.header.request_uri.to_s &&
            req.header['X-Trace'].first =~ /^2B[0-9,A-F]*01$/
      end

      TraceView::API.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get_async('http://127.0.0.11:8101/', nil, [['some_header', 'some_value'], ['some_header2', 'some_value2']])
      end
    end

    def test_async_tracing_sampling_hash_headers
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.16:8101/' == req.header.request_uri.to_s &&
        req.header['X-Trace'].first =~ /^2B[0-9,A-F]*01$/
      end

      TraceView::API.start_trace('httpclient_test') do
        clnt = HTTPClient.new
        clnt.get_async('http://127.0.0.16:8101/', nil, { 'some_header' => 'some_value', 'some_header2' => 'some_value2' })
      end
    end

    def test_async_tracing_not_sampling
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.12:8101/' == req.header.request_uri.to_s &&
            req.header['X-Trace'].first =~  /^2B[0-9,A-F]*00$/ &&
            req.header['X-Trace'].first !~ /^2B0*$/
      end

      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::API.start_trace('httpclient_test') do
          clnt = HTTPClient.new
          clnt.get_async('http://127.0.0.12:8101/')
        end
      end
    end

    def test_async_no_xtrace
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.13:8101/' == req.header.request_uri.to_s &&
            req.header['X-Trace'].empty?
      end

      clnt = HTTPClient.new
      clnt.get_async('http://127.0.0.13:8101/')
    end

    def test_async_blacklisted
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.14:8101/' == req.header.request_uri.to_s &&
            req.header['X-Trace'].empty?
      end

      TraceView.config_lock.synchronize do
        TraceView::Config.blacklist << '127.0.0.14'
        TraceView::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          clnt.get_async('http://127.0.0.14:8101/')
        end
      end
    end

    def test_async_not_sampling_blacklisted
      WebMock.disable!

      Thread.expects(:new).yields   # continue without forking off a thread

      HTTPClient.any_instance.expects(:do_get_stream_without_traceview).with do |req, _, _|
        'http://127.0.0.15:8101/' == req.header.request_uri.to_s &&
            req.header['X-Trace'].empty?
      end

      TraceView.config_lock.synchronize do
        TraceView::Config[:sample_rate] = 0
        TraceView::Config.blacklist << '127.0.0.15'
        TraceView::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          clnt.get_async('http://127.0.0.15:8101/')
        end
      end
    end
  end
end