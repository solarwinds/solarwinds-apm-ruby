# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/minitest'

  class FaradayMockedTest < Minitest::Test

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

    def test_tracing_sampling
      stub_request(:get, "http://127.0.0.1:8101/")

      AppOpticsAPM::API.start_trace('faraday_test') do
        conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
        conn.get
      end

      assert_requested :get, "http://127.0.0.1:8101/", times: 1
      refute_requested :get, "http://127.0.0.1:8101/", headers: {'traceparent'=>/^.*$/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_tracing_not_sampling
      stub_request(:get, "http://127.0.0.12:8101/")

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('faraday_test') do
          conn = Faraday.new(:url => 'http://127.0.0.12:8101') do |faraday|
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
          end
          conn.get
        end
      end

      assert_requested :get, "http://127.0.0.12:8101/", times: 1
      refute_requested :get, "http://127.0.0.12:8101/", headers: {'traceparent'=>/^.*$/}
      refute AppOpticsAPM::Context.isValid
    end

    def test_no_xtrace
      stub_request(:get, "http://127.0.0.3:8101/")

      conn = Faraday.new(:url => 'http://127.0.0.3:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      refute_requested :get, "http://127.0.0.3:8101/", headers: {'Traceparent'=>/^.*$/}
    end

    def test_blacklisted
      stub_request(:get, "http://127.0.0.4:8101/")

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.4'
        AppOpticsAPM::API.start_trace('faraday_test') do
          conn = Faraday.new(:url => 'http://127.0.0.4:8101') do |faraday|
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
          end
          conn.get
        end
      end

      assert_requested :get, "http://127.0.0.4:8101/", times: 1
      refute_requested :get, "http://127.0.0.4:8101/", headers: {'Traceparent'=>/^.*$/}
      refute AppOpticsAPM::Context.isValid
    end

    ##### with uninstrumented middleware #####

    def test_tracing_sampling_patron
      stub_request(:get, "http://127.0.0.1:8101/")

      AppOpticsAPM::API.start_trace('faraday_test') do
        conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
          faraday.adapter :patron # use an uninstrumented middleware
        end
        conn.get
      end

      assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
        assert_trace_headers(req.headers)
        assert sampled?(req.headers['Traceparent'])
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_tracing_not_sampling_patron
      stub_request(:get, "http://127.0.0.12:8101/")

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('faraday_test') do
          conn = Faraday.new(:url => 'http://127.0.0.12:8101') do |faraday|
            faraday.adapter :patron # use an uninstrumented middleware
          end
          conn.get
        end
      end

      assert_requested(:get, "http://127.0.0.12:8101/", times: 1) do |req|
        assert_trace_headers(req.headers)
        refute sampled?(req.headers)
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_no_xtrace_patron
      stub_request(:get, "http://127.0.0.3:8101/")

      conn = Faraday.new(:url => 'http://127.0.0.3:8101') do |faraday|
        faraday.adapter :patron # use an uninstrumented middleware
      end
      conn.get

      assert_requested :get, "http://127.0.0.3:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.3:8101/", headers: {'Traceparent'=>/^.*$/}
    end

    def test_blacklisted_patron
      stub_request(:get, "http://127.0.0.4:8101/")

      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.4'
        AppOpticsAPM::API.start_trace('faraday_test') do
          conn = Faraday.new(:url => 'http://127.0.0.4:8101') do |faraday|
            faraday.adapter :patron # use an uninstrumented middleware
          end
          conn.get
        end
      end

      assert_requested :get, "http://127.0.0.4:8101/", times: 1
      assert_not_requested :get, "http://127.0.0.4:8101/", headers: {'Traceparent'=>/^.*$/}
      refute AppOpticsAPM::Context.isValid
    end
  end
end
