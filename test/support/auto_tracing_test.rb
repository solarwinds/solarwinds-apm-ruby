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

  def test_trace_when_default_tm_dj
    TV::API.start_trace('delayed_job-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_sidekiq
    TV::API.start_trace('sidekiq-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_resque
    TV::API.start_trace('resque-worker') do
      TraceView.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_rabbitmq
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
