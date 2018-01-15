# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class AutoTraceTest  < Minitest::Test
  def setup
    @tm = AppOpticsAPM::Config[:tracing_mode]
  end

  def teardown
    AppOpticsAPM::Config[:tracing_mode] = @tm
  end

  def test_trace_when_default_tm_dj
    AppOpticsAPM::API.start_trace('delayed_job-worker') do
      AppOpticsAPM.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_sidekiq
    AppOpticsAPM::API.start_trace('sidekiq-worker') do
      AppOpticsAPM.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_resque
    AppOpticsAPM::API.start_trace('resque-worker') do
      AppOpticsAPM.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_rabbitmq
    AppOpticsAPM::API.start_trace('rabbitmq-consumer') do
      AppOpticsAPM.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    AppOpticsAPM::Config[:tracing_mode] = :never

    AppOpticsAPM::API.start_trace('delayed_job-worker') do
      AppOpticsAPM.tracing?.must_equal false
    end

    AppOpticsAPM::API.start_trace('asdf') do
      AppOpticsAPM.tracing?.must_equal false
    end
  end
end
