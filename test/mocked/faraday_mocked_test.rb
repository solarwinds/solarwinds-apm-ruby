# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock/minitest'
require 'mocha/minitest'

require 'rack/test'
require 'rack/lobster'
require 'solarwinds_apm/inst/rack'

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
      use SolarWindsAPM::Rack
      map "/out" do
        run Proc.new {
          conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
            # use an uninstrumented middleware to get span from faraday
            faraday.adapter :patron
          end
          conn.get
          [200, { "Content-Type" => "text/html" }, ['Hello SolarWindsAPM!']]
        }
      end
    }
  end

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
    clear_all_traces
  end

  def test_tracing_sampling
    stub_request(:get, "http://127.0.0.1:8101/")

    SolarWindsAPM::SDK.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end
      conn.get
    end

    assert_requested :get, "http://127.0.0.1:8101/", times: 1
    refute_requested :get, "http://127.0.0.1:8101/", headers: { 'traceparent' => /^.*$/ }
    refute SolarWindsAPM::Context.isValid
  end

  def test_tracing_not_sampling
    stub_request(:get, "http://127.0.0.12:8101/")

    SolarWindsAPM.config_lock.synchronize do
      SolarWindsAPM::Config[:sample_rate] = 0
      SolarWindsAPM::SDK.start_trace('faraday_test') do
        conn = Faraday.new(:url => 'http://127.0.0.12:8101') do |faraday|
          faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
        end
        conn.get
      end
    end

    assert_requested :get, "http://127.0.0.12:8101/", times: 1
    refute_requested :get, "http://127.0.0.12:8101/", headers: { 'traceparent' => /^.*$/ }
    refute SolarWindsAPM::Context.isValid
  end

  def test_no_xtrace
    stub_request(:get, "http://127.0.0.3:8101/")

    conn = Faraday.new(:url => 'http://127.0.0.3:8101') do |faraday|
      faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
    end
    conn.get

    assert_requested :get, "http://127.0.0.3:8101/", times: 1
    refute_requested :get, "http://127.0.0.3:8101/", headers: { 'Traceparent' => /^.*$/ }
  end

  ##### with uninstrumented middleware #####

  def test_tracing_sampling_patron
    stub_request(:get, "http://127.0.0.1:8101/")

    SolarWindsAPM::SDK.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron # use an uninstrumented middleware
      end
      conn.get
    end

    assert_requested(:get, "http://127.0.0.1:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, true)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_tracing_not_sampling_patron
    stub_request(:get, "http://127.0.0.12:8101/")

    SolarWindsAPM.config_lock.synchronize do
      SolarWindsAPM::Config[:sample_rate] = 0
      SolarWindsAPM::SDK.start_trace('faraday_test') do
        conn = Faraday.new(:url => 'http://127.0.0.12:8101') do |faraday|
          faraday.adapter :patron # use an uninstrumented middleware
        end
        conn.get
      end
    end

    assert_requested(:get, "http://127.0.0.12:8101/", times: 1) do |req|
      assert_trace_headers(req.headers, false)
    end
    refute SolarWindsAPM::Context.isValid
  end

  def test_no_xtrace_patron
    stub_request(:get, "http://127.0.0.3:8101/")

    conn = Faraday.new(:url => 'http://127.0.0.3:8101') do |faraday|
      faraday.adapter :patron # use an uninstrumented middleware
    end
    conn.get

    assert_requested :get, "http://127.0.0.3:8101/", times: 1
    assert_not_requested :get, "http://127.0.0.3:8101/", headers: { 'Traceparent' => /^.*$/ }
  end

  ##### W3C tracestate propagation

  def test_propagation_simple_trace_state
    WebMock.disable!

    trace_id = 'a462ade6cfe479081764cc476aa98335'
    tracestring = "00-#{trace_id}-cb3468da6f06eefc-01"
    state = 'sw=cb3468da6f06eefc-01'
    headers = { traceparent: tracestring, tracestate: state }

    SolarWindsAPM::SDK.start_trace('faraday_tests', headers: headers) do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron # use an uninstrumented middleware
      end
      conn.get

      assert_trace_headers(conn.headers, true)
      assert_equal trace_id, SolarWindsAPM::TraceString.trace_id(conn.headers['traceparent'])
      refute_equal state, conn.headers['tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_simple_trace_state_not_tracing
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'sw=cb3468da6f06eefc01'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
      faraday.adapter :patron # use an uninstrumented middleware
    end
    conn.get

    assert_equal trace_id, conn.headers['traceparent']
    assert_equal state, conn.headers['tracestate']

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_multimember_trace_state
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }

    SolarWindsAPM::SDK.start_trace('faraday_tests', headers: headers) do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron # use an uninstrumented middleware
      end
      conn.get

      assert_trace_headers(conn.headers, true)
      assert_equal task_id, SolarWindsAPM::TraceString.trace_id(conn.headers['traceparent'])
      assert_equal "sw=#{SolarWindsAPM::TraceString.span_id_flags(conn.headers['traceparent'])},aa= 1234,%%cc=%%%45",
                   conn.headers['tracestate']
    end

    refute SolarWindsAPM::Context.isValid
  end

  def test_propagation_multimember_trace_state_not_tracing
    WebMock.disable!

    task_id = 'a462ade6cfe479081764cc476aa98335'
    trace_id = "00-#{task_id}-cb3468da6f06eefc-01"
    state = 'aa= 1234, sw=cb3468da6f06eefc-01,%%cc=%%%45'
    headers = { traceparent: trace_id, tracestate: state }
    SolarWindsAPM.trace_context = SolarWindsAPM::TraceContext.new(headers)

    conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
      faraday.adapter :patron # use an uninstrumented middleware
    end
    conn.get

    assert_equal trace_id, conn.headers['traceparent']
    assert_equal state, conn.headers['tracestate']

    refute SolarWindsAPM::Context.isValid
  end

end
