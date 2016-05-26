# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'traceview/inst/rack'

class AVWTraceTest  < Minitest::Test
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
    TraceView::Config[:tracing_mode] = :always
  end

  def test_avw_collection_with_through
    # Skip under JRuby/Joboe for now. Due to Java instrumentation
    # variation that is being investigated in TVI-2348
    skip if defined?(JRUBY_VERSION)

    TV::Config[:tracing_mode] = :through
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    response = get "/lobster"
    response.header.key?('X-Trace').must_equal false
  end

  def test_avw_collection_with_always
    # Skip under JRuby/Joboe for now. Due to Java instrumentation
    # variation that is being investigated in TVI-2348
    skip if defined?(JRUBY_VERSION)

    TV::Config[:tracing_mode] = :always
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    response = get "/lobster"
    response.header.key?('X-Trace').must_equal true
  end

  def test_avw_collection_with_never
    # FIXME: We are forced to skp this test because the tracing mode in liboboe
    # is thread local and the background webapp doesn't play nicely when the
    # tracing mode is changed in this thread.
    skip
    TV::Config[:tracing_mode] = :never
    header('X-TV-Meta', 'abcdefghijklmnopqrstuvwxyz')

    response = get "/lobster"
    response.header.key?('X-Trace').must_equal false
  end
end
