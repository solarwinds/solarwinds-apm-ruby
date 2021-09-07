# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'mocha/minitest'
  require 'net/http'

  class HTTPMockedTest < Minitest::Test

    # prepend HttpMock to check if appoptics is in the ancestors chain
    # resorting to this solution because a method instrumented by using :prepend
    # can't be mocked with mocha

    def setup
      AppOpticsAPM::Context.clear

      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!

      AppOpticsAPM::Config[:sample_rate] = 1000000
      AppOpticsAPM::Config[:tracing_mode] = :enabled
      AppOpticsAPM::Config[:blacklist] = []
    end

    def test_tracing_sampling
      AppOpticsAPM::API.start_trace('net_http_test') do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          xt = AppOpticsAPM::Context.toString
          request = Net::HTTP::Get.new(uri)
          refute request['traceparent']

          res = http.request(request)
          # did we instrument?
          assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)

          assert request['traceparent']
          assert res['x-trace']
          assert AppOpticsAPM::XTrace.sampled?(res['x-trace'])
          refute_equal xt, request['traceparent']
          refute_equal xt, res['x-trace']
        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_tracing_not_sampling
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::API.start_trace('Net::HTTP_test') do
          uri = URI('http://127.0.0.1:8101/?q=1')
          Net::HTTP.start(uri.host, uri.port) do |http|
            xt = AppOpticsAPM::Context.toString

            request = Net::HTTP::Get.new(uri)
            refute request['traceparent']
            res = http.request(request) # Net::HTTPResponse object
            # did we instrument?
            assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)
            assert request['traceparent']
            assert res['x-trace']
            refute AppOpticsAPM::XTrace.sampled?(res.to_hash['x-trace'])
            assert_equal xt, request['traceparent']
            assert_equal xt, res['x-trace']
          end

        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_no_xtrace
      uri = URI('http://127.0.0.1:8101/?q=1')
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)
        res = http.request(request) # Net::HTTPResponse object

        assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)
        refute request['traceparent']
        # the result may have an x-trace from the outbound call and that is ok
      end
    end

    def test_blacklisted
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config.blacklist << '127.0.0.1'
        AppOpticsAPM::API.start_trace('Net::HTTP_tests') do
          uri = URI('http://127.0.0.1:8101/?q=1')
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Get.new(uri)
            res = http.request(request) # Net::HTTPResponse object
            # did we instrument?
            assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)
            refute request['tracepearent']
            # the result should not have an x-trace
            refute res['x-trace']
          end
        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    def test_not_sampling_blacklisted
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:sample_rate] = 0
        AppOpticsAPM::Config.blacklist << '127.0.0.1'
        AppOpticsAPM::API.start_trace('Net::HTTP_tests') do
          uri = URI('http://127.0.0.1:8101/?q=1')
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Get.new(uri)
            res = http.request(request) # Net::HTTPResponse object
            # did we instrument?
            assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)
            refute request['traceparent']
            # the result should either not have an x-trace or
            refute res['x-trace']
          end
        end
      end
      refute AppOpticsAPM::Context.isValid
    end

    # ========== make sure request headers are preserved =============================
    def test_preserves_custom_headers
      AppOpticsAPM::API.start_trace('Net::HTTP_tests') do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)
          request['Custom'] = 'specialvalue'
          res = http.request(request) # Net::HTTPResponse object
          # did we instrument?
          assert http.class.ancestors.include?(AppOpticsAPM::Inst::NetHttp)
          assert request['traceparent']
          assert res['x-trace']
          assert_equal 'specialvalue', request['Custom']
        end
      end
      refute AppOpticsAPM::Context.isValid
    end
  end
end
