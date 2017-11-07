# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    @tm = TraceView::Config[:tracing_mode]
    TraceView::Config[:tracing_mode] = :always
  end

  def teardown
    TraceView::Config[:tracing_mode] = @tm
  end

  def test_trace_when_always
    TV::API.start_trace(:test_always) do
      TraceView.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    TraceView::Config[:tracing_mode] = :never

    TV::API.start_trace(:test_never) do
      TraceView.tracing?.must_equal false
    end

    TV::API.start_trace('asdf') do
      TraceView.tracing?.must_equal false
    end
  end
end
