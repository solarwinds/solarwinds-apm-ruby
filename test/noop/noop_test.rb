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
      use AppOpticsAPM::Rack
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
    assert AppOpticsAPM::Rack.noop?, 'This is not running in noop mode.'
  end

  def test_appoptics_config_doesnt_barf
    tm = AppOpticsAPM::Config[:tracing_mode]
    vb = AppOpticsAPM::Config[:verbose]
    la = AppOpticsAPM::Config[:rack][:log_args]

    # Test that we can set various things into AppOpticsAPM::Config still
    AppOpticsAPM::Config[:tracing_mode] = :enabled
    AppOpticsAPM::Config[:verbose] = false
    AppOpticsAPM::Config[:rack][:log_args] = true

    assert_equal :enabled, AppOpticsAPM::Config[:tracing_mode]
    assert_equal false, AppOpticsAPM::Config[:verbose]
    assert_equal true, AppOpticsAPM::Config[:rack][:log_args]

    # Restore the originals
    AppOpticsAPM::Config[:tracing_mode] = tm
    AppOpticsAPM::Config[:verbose] = vb
    AppOpticsAPM::Config[:rack][:log_args] = la
  end

  # ===== Make sure the AppOpticsAPM::Inst module does not exist ============================
  # this is the module in which all the instrumented methods are defined
  def test_not_instrumented
    refute ::AppOpticsAPM.const_defined?('Inst', false), 'This should be noop mode, but instrumentation was found.'
  end

  # ===== Make sure the frameworks are not instrumented =====================================
  def test_rails_not_instrumented
    refute ::AppOpticsAPM.const_defined?('Rails', false), 'This should be noop mode, but Rails is instrumented.'
  end

  def test_sinatra_not_instrumented
    refute ::AppOpticsAPM.const_defined?('Sinatra', false), 'This should be noop mode, but Sinatra is instrumented.'
  end

  def test_grape_not_instrumented
    refute ::AppOpticsAPM.const_defined?('Grape', false), 'This should be noop mode, but Grape is instrumented.'
  end

  def test_padrino_not_instrumented
    refute ::AppOpticsAPM.const_defined?('Padrino', false), 'This should be noop mode, but Padrino is instrumented.'
  end

  # ===== Make sure the methods we document as SDK don't barf in noop mode ==================

  def test_api_start_trace_doesnt_barf
    AppOpticsAPM::API.start_trace('noop_test')  do
      AppOpticsAPM::API.trace('blah_block') do
        "this block should not be traced"
      end
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_sdk_start_trace_doesnt_barf
    AppOpticsAPM::SDK.start_trace('noop_test')  do
      AppOpticsAPM::SDK.trace('blah_block') do
        "this block should not be traced"
      end
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end


  def test_trace_doesnt_barf
    AppOpticsAPM::API.trace('noop_test')  do
      "this block should not be traced"
    end

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_trace_method_doesnt_barf
    AppOpticsAPM::SDK.trace_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_legacy_profile_method_doesnt_barf
    AppOpticsAPM.logger.expects(:warn) # we are expecting a deprecation warning

    AppOpticsAPM::API.profile_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_info_doesnt_barf
    AppOpticsAPM::API.log_info(nil, {:ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_init_doesnt_barf
    AppOpticsAPM::API.log_init(nil, {:ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_log_end_doesnt_barf
    AppOpticsAPM::API.log_end(nil, {:ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_set_transaction_name_doesnt_barf
    AppOpticsAPM::API.set_transaction_name("should not throw an exception")
  end

  def test_current_trace_doesnt_barf
    trace = AppOpticsAPM::SDK.current_trace

    assert trace, 'it should return a trace when in noop'
  end

  def test_current_trace_traceid_doesnt_barf
    trace = AppOpticsAPM::SDK.current_trace

    assert trace.id, 'it should return a trace id when in noop'
    assert_equal '0000000000000000000000000000000000000000-0', trace.id
  end

  def test_current_trace_for_log_doesnt_barf
    trace = AppOpticsAPM::SDK.current_trace

    assert trace.for_log, 'it should create a log string when in noop'
    assert_equal '', trace.for_log
  end
end

