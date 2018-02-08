# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/mini_test'
  WebMock.allow_net_connect!
  WebMock.reset!

  class ExconTest < Minitest::Test

    def setup
      AppOpticsAPM::Context.clear
      WebMock.enable!
      WebMock.disable_net_connect!
      AppOpticsAPM.config_lock.synchronize {
        @sample_rate = AppOpticsAPM::Config[:sample_rate]
        @tracing_mode= AppOpticsAPM::Config[:tracing_mode]
      }
    end

    def teardown
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:sample_rate] = @sample_rate
        AppOpticsAPM::Config[:tracing_mode] = @tracing_mode
        AppOpticsAPM::Config[:blacklist] = []
      }
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
    end

    # ========== excon get =================================

    def test_xtrace_no_trace
      stub_request(:get, "http://127.0.0.6:8101/")

      AppOpticsAPM.config_lock.synchronize do
        ::Excon.get("http://127.0.0.6:8101/")
      end

      assert_requested :get, "http://127.0.0.6:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.6:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    def test_xtrace_tracing
      stub_request(:get, "http://127.0.0.7:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('excon_tests') do
        ::Excon.get("http://127.0.0.7:8101/")
      end

      assert_requested :get, "http://127.0.0.7:8101/", times: 1
      assert_requested :get, "http://127.0.0.7:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]{56}01/}, times: 1
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_tracing_not_sampling
      stub_request(:get, "http://127.0.0.4:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('excon_test') do
          ::Excon.get("http://127.0.0.4:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.4:8101/", times: 1
      assert_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.4:8101/", headers: {'X-Trace'=>/^2B0*$/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_tracing_blacklisted
      stub_request(:get, "http://127.0.0.3:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.3'
        AppOpticsAPM::API.start_trace('excon_tests') do
          ::Excon.get("http://127.0.0.3:8101/")
        end
      end

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.3:8101/", headers: {'X-Trace'=>/.*/}
      refute AppOpticsAPM::Context.isValid
    end

    # ========== excon pipelined =================================

    def test_xtrace_pipelined_tracing
      stub_request(:get, "http://127.0.0.5:8101/").to_return(status: 200, body: "", headers: {})
      stub_request(:put, "http://127.0.0.5:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('excon_tests') do
        connection = ::Excon.new('http://127.0.0.5:8101/')
        connection.requests([{:method => :get}, {:method => :put}])
      end

      assert_requested :get, "http://127.0.0.5:8101/", times: 1
      assert_requested :put, "http://127.0.0.5:8101/", times: 1
      assert_requested :get, "http://127.0.0.5:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*01$/}, times: 1
      assert_requested :put, "http://127.0.0.5:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*01$/}, times: 1
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_pipelined_tracing_not_sampling
      stub_request(:get, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})
      stub_request(:put, "http://127.0.0.2:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('excon_tests') do
          connection = ::Excon.new('http://127.0.0.2:8101/')
          connection.requests([{:method => :get}, {:method => :put}])
        end
      end

      assert_requested :get, "http://127.0.0.2:8101/", times: 1
      assert_requested :put, "http://127.0.0.2:8101/", times: 1
      assert_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_requested :put, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B[0-9,A-F]*00$/}, times: 1
      assert_not_requested :get, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B0*$/}
      assert_not_requested :put, "http://127.0.0.2:8101/", headers: {'X-Trace'=>/^2B0*$/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_xtrace_pipelined_no_trace
      stub_request(:get, "http://127.0.0.8:8101/").to_return(status: 200, body: "", headers: {})
      stub_request(:put, "http://127.0.0.8:8101/").to_return(status: 200, body: "", headers: {})

      connection = ::Excon.new('http://127.0.0.8:8101/')
      connection.requests([{:method => :get}, {:method => :put}])

      assert_requested :get, "http://127.0.0.8:8101/", times: 1
      assert_requested :put, "http://127.0.0.8:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.8:8101/", headers: {'X-Trace'=>/^.*$/}
      assert_not_requested :put, "http://127.0.0.8:8101/", headers: {'X-Trace'=>/^.*$/}
    end

    def test_xtrace_pipelined_tracing_blacklisted
      stub_request(:get, "http://127.0.0.9:8101/").to_return(status: 200, body: "", headers: {})
      stub_request(:put, "http://127.0.0.9:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.9'
        AppOpticsAPM::API.start_trace('excon_tests') do
          connection = ::Excon.new('http://127.0.0.9:8101/')
          connection.requests([{:method => :get}, {:method => :put}])
        end
      end

      assert_requested :get, "http://127.0.0.9:8101/", times: 1
      assert_requested :put, "http://127.0.0.9:8101/", times: 1
      assert_not_requested :get, "http://127.9.0.8:8101/", headers: {'X-Trace'=>/^.*$/}
      assert_not_requested :put, "http://127.9.0.8:8101/", headers: {'X-Trace'=>/^.*$/}
      refute AppOpticsAPM::Context.isValid
    end

    # ========== excon make sure headers are preserved =============================
    def test_preserves_custom_headers
      stub_request(:get, "http://127.0.0.10:8101/").to_return(status: 200, body: "", headers: {})

      AppOpticsAPM::API.start_trace('excon_tests') do
        Excon.get('http://127.0.0.10:8101', headers: { 'Custom' => 'specialvalue' })
      end

      assert_requested :get, "http://127.0.0.10:8101/", headers: {'Custom'=>'specialvalue'}, times: 1
      refute AppOpticsAPM::Context.isValid
    end
  end
end

