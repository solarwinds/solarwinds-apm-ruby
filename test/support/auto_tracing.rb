# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class AutoTraceTest  < Minitest::Test
  def setup
    @tm = TraceView::Config[:tracing_mode]
  end

  def teardown
    TraceView::Config[:tracing_mode] = @tm
  end

  def test_entry_layers
    TraceView.entry_layer?('delayed_job-worker').must_equal true
    TraceView.entry_layer?('asdf-worker').must_equal false
  end

  def test_entry_layers_supports_symbols
    TraceView.entry_layer?(:'delayed_job-worker').must_equal true
    TraceView.entry_layer?(:asdfworker).must_equal false
  end

  def test_trace_when_default_tm
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace('delayed_job-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    TraceView::Config[:tracing_mode] = :never

    TV::API.start_trace('delayed_job-worker') do
      TraceView.tracing?.must_equal false
    end
  end
end
