# Copyright (c) 2016 SolarWinds, LLC.
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
    TraceView.entry_layer?('sidekiq-worker').must_equal true
    TraceView.entry_layer?('resque-worker').must_equal true
    TraceView.entry_layer?('rabbitmq-consumer').must_equal true
    TraceView.entry_layer?('asdf-worker').must_equal false
  end

  def test_entry_layers_supports_symbols
    TraceView.entry_layer?(:'delayed_job-worker').must_equal true
    TraceView.entry_layer?(:'resque-worker').must_equal true
    TraceView.entry_layer?(:'rabbitmq-consumer').must_equal true
    TraceView.entry_layer?(:asdfworker).must_equal false
  end

  def test_trace_when_default_tm_dj
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace('delayed_job-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_sidekiq
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace('sidekiq-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_resque
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace('resque-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_rabbitmq
    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace('rabbitmq-consumer') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    TraceView::Config[:tracing_mode] = :never

    TV::API.start_trace('delayed_job-worker') do
      TraceView.tracing?.must_equal false
    end

    TV::API.start_trace('asdf') do
      TraceView.tracing?.must_equal false
    end
  end
end
