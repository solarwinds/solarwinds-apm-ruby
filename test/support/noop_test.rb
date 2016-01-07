# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'traceview/inst/rack'
require 'net/http'

class NoopTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    TraceView.loaded = false
  end

  def teardown
    TraceView.loaded = true
  end

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use TraceView::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_requests_still_work
    clear_all_traces

    get "/lobster"

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_tracing_api_doesnt_barf
    TraceView::API.start_trace('noop_test')  do
      TraceView::API.trace('blah_block') do
        "this block should not be traced"
      end
    end

    TraceView::API.log_start('noop_test')
    TraceView::API.log_info(nil, {:ok => :yeah })
    TraceView::API.log_exception(nil, Exception.new("yeah ok"))
    TraceView::API.log_end('noop_test')

    traces = get_all_traces
    assert_equal 0, traces.count, "generate no traces"
  end

  def test_method_profiling_doesnt_barf
    TraceView::API.profile_method(Array, :sort)

    x = [1, 3, 2]
    assert_equal [1, 2, 3], x.sort
  end

  def test_tv_config_doesnt_barf
    tm = TV::Config[:tracing_mode]
    vb = TV::Config[:verbose]
    la = TV::Config[:rack][:log_args]

    # Test that we can set various things into TraceView::Config still
    TV::Config[:tracing_mode] = :always
    TV::Config[:verbose] = false
    TV::Config[:rack][:log_args] = true

    assert_equal :always,  TV::Config[:tracing_mode]
    assert_equal false,    TV::Config[:verbose]
    assert_equal true,     TV::Config[:rack][:log_args]

    # Restore the originals
    TV::Config[:tracing_mode] = tm
    TV::Config[:verbose] = vb
    TV::Config[:rack][:log_args] = la
  end
end

