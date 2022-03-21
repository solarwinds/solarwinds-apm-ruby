# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#

# Force noop by setting the platform to something we don't support
RUBY_PLATFORM = 'noop'

# These tests assert:
# - that there is no instrumentation nor tracing in noop mode
# - that the 'official' SDK methods don't create

require 'minitest_helper'
require 'rack/lobster'
require 'net/http'
require 'mocha/minitest'
require 'graphql'

class NoopTest < Minitest::Test
  include Rack::Test::Methods

  class ArrayTest < Array; end

  def setup
    clear_all_traces
  end

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use SolarWindsAPM::Rack
      map '/lobster' do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_requests_still_work
    get '/lobster'
    traces = get_all_traces
    assert_equal 0, traces.count, 'generate no traces'
    assert SolarWindsAPM::Rack.noop?, 'This is not running in noop mode.'
  end

  def test_appoptics_config_doesnt_barf
    tm = SolarWindsAPM::Config[:tracing_mode]
    vb = SolarWindsAPM::Config[:verbose]
    la = SolarWindsAPM::Config[:rack][:log_args]

    # Test that we can set various things into SolarWindsAPM::Config still
    SolarWindsAPM::Config[:tracing_mode] = :enabled
    SolarWindsAPM::Config[:verbose] = false
    SolarWindsAPM::Config[:rack][:log_args] = true

    assert_equal :enabled, SolarWindsAPM::Config[:tracing_mode]
    assert_equal false, SolarWindsAPM::Config[:verbose]
    assert_equal true, SolarWindsAPM::Config[:rack][:log_args]

    # Restore the originals
    SolarWindsAPM::Config[:tracing_mode] = tm
    SolarWindsAPM::Config[:verbose] = vb
    SolarWindsAPM::Config[:rack][:log_args] = la
  end

  # ===== Make sure the SolarWindsAPM::Inst module does not exist ============================
  # this is the module in which all the instrumented methods are defined
  def test_not_instrumented
    refute ::SolarWindsAPM.const_defined?('Inst', false), 'This should be noop mode, but instrumentation was found.'
  end

  # ===== Make sure the frameworks are not instrumented =====================================
  def test_rails_not_instrumented
    refute ::SolarWindsAPM.const_defined?('Rails', false), 'This should be noop mode, but Rails is instrumented.'
  end

  def test_sinatra_not_instrumented
    refute ::SolarWindsAPM.const_defined?('Sinatra', false), 'This should be noop mode, but Sinatra is instrumented.'
  end

  def test_grape_not_instrumented
    refute ::SolarWindsAPM.const_defined?('Grape', false), 'This should be noop mode, but Grape is instrumented.'
  end

  def test_padrino_not_instrumented
    refute ::SolarWindsAPM.const_defined?('Padrino', false), 'This should be noop mode, but Padrino is instrumented.'
  end

  def test_graphql_not_instrumented
    refute GraphQL::Schema.plugins.find { |plugin| plugin == GraphQL::Tracing::AppOpticsTracing },
           'failed: This should be noop mode, but GraphQL is instrumented.'
  end

  # ===== Make sure the methods we document as SDK don't barf in noop mode ==================

  def test_api_start_trace_doesnt_barf
    SolarWindsAPM::SDK.start_trace('noop_test') do
      SolarWindsAPM::SDK.trace('blah_block') do
        "this block should not be traced"
      end
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_sdk_start_trace_doesnt_barf
    SolarWindsAPM::SDK.start_trace('noop_test') do
      SolarWindsAPM::SDK.trace('blah_block') do
        "this block should not be traced"
      end
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_trace_doesnt_barf
    SolarWindsAPM::SDK.trace('noop_test') do
      "this block should not be traced"
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_trace_method_doesnt_barf
    SolarWindsAPM::SDK.trace_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_info_doesnt_barf
    SolarWindsAPM::API.log_info(nil, { :ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_init_doesnt_barf
    SolarWindsAPM::API.log_init(nil, { :ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_end_doesnt_barf
    SolarWindsAPM::API.log_end(nil, { :ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_set_transaction_name_doesnt_barf
    SolarWindsAPM::API.set_transaction_name("should not throw an exception")
  end

  def test_current_trace_doesnt_barf
    trace = SolarWindsAPM::SDK.current_trace_info

    assert trace, 'it should return a trace when in noop'
  end

  def test_current_trace_traceid_doesnt_barf
    trace = SolarWindsAPM::SDK.current_trace_info

    assert trace.trace_id, 'it should return a trace id when in noop'
    assert_equal '00000000000000000000000000000000', trace.trace_id
    assert_equal '0000000000000000', trace.span_id
    assert_equal '00', trace.trace_flags
  end

  def test_current_trace_for_log_doesnt_barf
    trace = SolarWindsAPM::SDK.current_trace_info

    assert trace.for_log, 'it should create a log string when in noop'
    assert_equal '', trace.for_log
  end

  def test_increment_metrics_doesnt_barf
    SolarWindsAPM::SDK.increment_metric('dont_barf')
  end

  def test_summary_metrics_doesnt_barf
    SolarWindsAPM::SDK.summary_metric('dont_barf', 5)
  end

  def test_profiling_doesnt_barf
    SolarWindsAPM::Profiling.run do
      sleep 0.1
    end
  end

  def test_cprofiler_doesnt_barf
    SolarWindsAPM::CProfiler.set_interval(10)
  end
end

