# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if !defined?(JRUBY_VERSION)

  require 'minitest_helper'
  require 'webmock/minitest'
  require 'mocha/minitest'

  require 'rack/test'
  require 'rack/lobster'
  require 'appoptics_apm/inst/rack'

  #####################################################
  # FYI:
  # Faraday only adds tracing when it is
  # not using an adapter that is instrumented
  #
  # otherwise we would get two spans for the same call
  #####################################################

  class FaradayMockedTest < Minitest::Test

    include Rack::Test::Methods

    def app
      @app = Rack::Builder.new {
        # use Rack::CommonLogger
        # use Rack::ShowExceptions
        use AppOpticsAPM::Rack
        map "/out" do
          run Proc.new {
            conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
              # use an uninstrumented middleware to get span from faraday
              faraday.adapter :patron
            end
            conn.get
            [200, {"Content-Type" => "text/html"}, ['Hello AppOpticsAPM!']]
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
      @blacklist = AppOpticsAPM::Config[:blacklist]

      AppOpticsAPM::Config[:sample_rate] = 1000000
      AppOpticsAPM::Config[:tracing_mode] = :enabled
      AppOpticsAPM::Config[:blacklist] = []
    end

    def teardown
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
      AppOpticsAPM::Config[:tracing_mode] = @tracing_mode
      AppOpticsAPM::Config[:blacklist] = @blacklist

      AppOpticsAPM.trace_context = nil
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
        assert_trace_headers(req.headers, true)
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
        assert_trace_headers(req.headers, false)
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

    ##### W3C tracestate propagation

    def test_propagation_simple_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc01'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      AppOpticsAPM::API.start_trace('faraday_tests', AppOpticsAPM.trace_context.xtrace) do
        conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
          faraday.adapter :patron  # use an uninstrumented middleware
        end
        conn.get

        assert_trace_headers(conn.headers, true)
        assert_equal task_id, AppOpticsAPM::TraceParent.task_id(conn.headers['traceparent'])
        refute_equal state, conn.headers['tracestate']
      end

      refute AppOpticsAPM::Context.isValid
    end


    def test_propagation_simple_trace_state_not_tracing
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'sw=cb3468da6f06eefc01'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron  # use an uninstrumented middleware
      end
      conn.get

      assert_equal trace_id, conn.headers['traceparent']
      assert_equal state, conn.headers['tracestate']

      refute AppOpticsAPM::Context.isValid
    end

    def test_propagation_multimember_trace_state
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      AppOpticsAPM::API.start_trace('faraday_tests', AppOpticsAPM.trace_context.xtrace) do
        conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
          faraday.adapter :patron  # use an uninstrumented middleware
        end
        conn.get

        assert_trace_headers(conn.headers, true)
        assert_equal task_id, AppOpticsAPM::TraceParent.task_id(conn.headers['traceparent'])
        assert_equal "sw=#{AppOpticsAPM::TraceParent.edge_id_flags(conn.headers['traceparent'])},aa= 1234,%%cc=%%%45",
                     conn.headers['tracestate']
      end

      refute AppOpticsAPM::Context.isValid
    end

    def test_propagation_multimember_trace_state_not_tracing
      WebMock.disable!

      task_id = 'a462ade6cfe479081764cc476aa98335'
      trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
      state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
      AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_id, state)

      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron  # use an uninstrumented middleware
      end
      conn.get

      assert_equal trace_id, conn.headers['traceparent']
      assert_equal state, conn.headers['tracestate']

      refute AppOpticsAPM::Context.isValid
    end

  end
end
