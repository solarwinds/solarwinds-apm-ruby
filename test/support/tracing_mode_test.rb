# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    @tm = TraceView::Config[:tracing_mode]
  end

  def teardown
    TraceView::Config[:tracing_mode] = @tm
  end

  def test_dont_start_trace_when_through
    # The test suite detects that we are in test mode and always
    # samples regardless of tracing mode
    skip
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace(:test_through) do
      TraceView.tracing?.must_equal false
    end
  end

  def test_dont_start_trace_when_through_with_avw
    # The test suite detects that we are in test mode and always
    # samples regardless of tracing mode
    skip
    TraceView::Config[:tracing_mode] = :through

    report_kvs = { 'X-TV-Meta' => :fake_avw_string }
    TV::API.start_trace(:test_through, nil, report_kvs) do
      TraceView.tracing?.must_equal false
    end
  end

  def test_trace_when_always
    TraceView::Config[:tracing_mode] = :always

    TV::API.start_trace(:test_always) do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_always_with_avw
    TraceView::Config[:tracing_mode] = :always

    report_kvs = { 'X-TV-Meta' => :fake_avw_string }
    TV::API.start_trace(:test_always, nil, report_kvs) do
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
