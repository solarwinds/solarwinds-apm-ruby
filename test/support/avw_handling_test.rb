# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'traceview/inst/rack'

class AutoTraceTest  < Minitest::Test
  include Rack::Test::Methods

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

  def setup
    clear_all_traces
    @tm = TraceView::Config[:tracing_mode]
  end

  def teardown
    TraceView::Config[:tracing_mode] = @tm
  end

  def test_avw_collection_with_through
    TV::Config[:tracing_mode] = :through
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    get "/lobster"

    traces = get_all_traces

    traces.count.must_equal 3
    traces[0]['TraceOrigin'].must_equal "avw_sampled"
    validate_outer_layers(traces, 'rack')
  end

  def test_avw_collection_with_always
    TV::Config[:tracing_mode] = :always
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    get "/lobster"

    traces = get_all_traces

    traces.count.must_equal 3
    traces[0]['TraceOrigin'].must_equal "always_sampled"
    validate_outer_layers(traces, 'rack')
  end

  def test_avw_collection_with_never
    TV::Config[:tracing_mode] = :never
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    get "/lobster"

    traces = get_all_traces
    traces.count.must_equal 0
  end
end
