# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    TraceView::Config[:tracing_mode] = :always
  end

  def test_dont_start_trace_when_through
    skip

    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace(:test_through) do
      TraceView.tracing?.must_equal false
    end
  end

  def test_trace_when_always
    skip

    TraceView::Config[:tracing_mode] = :always

    TV::API.start_trace(:test_always) do
      TraceView.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    skip

    TraceView::Config[:tracing_mode] = :never

    TV::API.start_trace(:test_never) do
      TraceView.tracing?.must_equal false
    end

    TV::API.start_trace('asdf') do
      TraceView.tracing?.must_equal false
    end
  end
end
