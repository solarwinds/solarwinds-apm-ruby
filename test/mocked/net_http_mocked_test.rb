# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'mocha/minitest'
  require 'net/http'

  require 'rack/test'
  require 'rack/lobster'
  require 'solarwinds_apm/inst/rack'

  class NetHTTPMockedTest < Minitest::Test

    include Rack::Test::Methods

    def app
      @app = Rack::Builder.new {
        # use Rack::CommonLogger
        # use Rack::ShowExceptions
        use SolarWindsAPM::Rack
        map "/out" do
          run Proc.new {
            uri = URI('http://127.0.0.1:8101/?q=1')
            Net::HTTP.start(uri.host, uri.port) do |http|
              req = Net::HTTP::Get.new(uri)
              http.request(req)
              [200,
               { "Content-Type" => "text/html" },
               [req['traceparent'], req['tracestate']]]
            end
          }
        end
      }
    end

    # prepend HttpMock to check if solarwinds_apm is in the ancestors chain
    # resorting to this solution because a method instrumented by using :prepend
    # can't be mocked with mocha

    def setup
      SolarWindsAPM::Context.clear

      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!

      @sample_rate = SolarWindsAPM::Config[:sample_rate]
      @tracing_mode = SolarWindsAPM::Config[:tracing_mode]

      SolarWindsAPM::Config[:sample_rate] = 1000000
      SolarWindsAPM::Config[:tracing_mode] = :enabled
    end

    def teardown
      SolarWindsAPM::Config[:sample_rate] = @sample_rate
      SolarWindsAPM::Config[:tracing_mode] = @tracing_mode

      SolarWindsAPM.trace_context = nil

      clear_all_traces
    end

    def test_tracing_sampling
      SolarWindsAPM::SDK.start_trace('net_http_test') do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          xt = SolarWindsAPM::Context.toString
          request = Net::HTTP::Get.new(uri)
          refute request['traceparent']

          res = http.request(request)
          # did we instrument?
          assert http.class.ancestors.include?(SolarWindsAPM::Inst::NetHttp)

          # `to_hash` returns a hash with values as arrays
          assert_trace_headers(request.to_hash.inject({}) { |h, (k, v)| h[k] = v[0]; h })
          assert res['x-trace']
          assert SolarWindsAPM::TraceString.sampled?(res['x-trace'])
          refute_equal xt, request['traceparent']
          refute_equal xt, res['x-trace']
        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    def test_tracing_not_sampling
      SolarWindsAPM.config_lock.synchronize do
        SolarWindsAPM::Config[:sample_rate] = 0
        SolarWindsAPM::SDK.start_trace('Net::HTTP_test') do
          uri = URI('http://127.0.0.1:8101/?q=1')
          Net::HTTP.start(uri.host, uri.port) do |http|
            trace = SolarWindsAPM::Context.toString
            request = Net::HTTP::Get.new(uri)
            refute request['traceparent']
            res = http.request(request) # Net::HTTPResponse object
            # did we instrument?
            assert http.class.ancestors.include?(SolarWindsAPM::Inst::NetHttp)

            # `to_hash` returns a hash with values as arrays
            assert_trace_headers(request.to_hash.inject({}) { |h, (k, v)| h[k] = v[0]; h })
            assert res['x-trace']
            refute SolarWindsAPM::TraceString.sampled?(res['x-trace'])
            assert_equal trace, request['traceparent']
            assert_equal trace, res['x-trace']
          end

        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    def test_no_xtrace
      uri = URI('http://127.0.0.1:8101/?q=1')
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)
        res = http.request(request) # Net::HTTPResponse object

        assert http.class.ancestors.include?(SolarWindsAPM::Inst::NetHttp)
        refute request['traceparent']
        # the result may have an x-trace from the outbound call and that is ok
      end
    end

    # ========== make sure request headers are preserved =============================
    def test_preserves_custom_headers
      SolarWindsAPM::SDK.start_trace('Net::HTTP_tests') do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)
          request['Custom'] = 'specialvalue'
          res = http.request(request) # Net::HTTPResponse object
          # did we instrument?
          assert http.class.ancestors.include?(SolarWindsAPM::Inst::NetHttp)

          # `to_hash` returns a hash with values as arrays
          assert_trace_headers(request.to_hash.inject({}) { |h, (k, v)| h[k] = v[0]; h })
          assert res['x-trace']
          assert_equal 'specialvalue', request['Custom']
        end
      end
      refute SolarWindsAPM::Context.isValid
    end

    ##### W3C tracestate propagation

    def test_propagation_simple_trace_state
      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc-01'
      headers = { traceparent: trace_id, tracestate: state }

      SolarWindsAPM::SDK.start_trace('net_http_test', headers: headers) do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request)
          headers = request.each_header.to_h

          assert_trace_headers(headers, true)
          assert_equal task_id, SolarWindsAPM::TraceString.trace_id(headers['traceparent'])
          refute_equal state, headers['tracestate']
        end
      end

      refute SolarWindsAPM::Context.isValid
    end

    def test_propagation_simple_trace_state_not_tracing
      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc-01'
      headers = { traceparent: trace_id, tracestate: state }
      SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

      uri = URI('http://127.0.0.1:8101/?q=1')
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request)
        headers = request.each_header.to_h

        assert_equal trace_id, headers['traceparent']
        assert_equal state, headers['tracestate']
      end

      refute SolarWindsAPM::Context.isValid
    end

    def test_propagation_multimember_trace_state
      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      headers = { traceparent: trace_id, tracestate: state }

      SolarWindsAPM::SDK.start_trace('net_http_test', headers: headers) do
        uri = URI('http://127.0.0.1:8101/?q=1')
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request)
          headers = request.each_header.to_h

          assert_trace_headers(headers, true)
          assert_equal task_id, SolarWindsAPM::TraceString.trace_id(headers['traceparent'])
          assert_equal "sw=#{SolarWindsAPM::TraceString.span_id_flags(headers['traceparent'])},aa= 1234,%%cc=%%%45",
                       headers['tracestate']
        end
      end

      refute SolarWindsAPM::Context.isValid
    end

  end
end
