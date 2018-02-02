# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#

# Force noop by setting the platform to something we don't support
RUBY_PLATFORM = 'noop'

require 'minitest_helper'
require 'rack/lobster'
require 'net/http'

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
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_requests_still_work
    get "/lobster"
    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_appoptics_config_doesnt_barf
    tm = AppOpticsAPM::Config[:tracing_mode]
    vb = AppOpticsAPM::Config[:verbose]
    la = AppOpticsAPM::Config[:rack][:log_args]

    # Test that we can set various things into AppOpticsAPM::Config still
    AppOpticsAPM::Config[:tracing_mode] = :always
    AppOpticsAPM::Config[:verbose] = false
    AppOpticsAPM::Config[:rack][:log_args] = true

    assert_equal :always, AppOpticsAPM::Config[:tracing_mode]
    assert_equal false, AppOpticsAPM::Config[:verbose]
    assert_equal true, AppOpticsAPM::Config[:rack][:log_args]

    # Restore the originals
    AppOpticsAPM::Config[:tracing_mode] = tm
    AppOpticsAPM::Config[:verbose] = vb
    AppOpticsAPM::Config[:rack][:log_args] = la
  end

  # ===== Make sure the methods we document as SDK don't barf in noop mode ================

  def test_start_trace_doesnt_barf
    AppOpticsAPM::API.start_trace('noop_test')  do
      AppOpticsAPM::API.trace('blah_block') do
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

  def test_method_profiling_doesnt_barf
    AppOpticsAPM::API.profile_method(ArrayTest, :sort)

    x = ArrayTest.new
    x.push(1).push(3).push(2)
    assert_equal [1, 2, 3], x.sort

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"  end

  def test_profile_doesnt_barf
    def fib(n)
      return n if n <= 1
      n + fib(n-1)
    end

    def computation(n)
      AppOpticsAPM::API.profile('fib', { :n => n }) do
        fib(n)
      end
    end

    result = computation(4)
    assert_equal 10, result


    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"  end

  def test_log_info_doesnt_barf
    AppOpticsAPM::API.log_info(nil, {:ok => :yeah })

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end
end

