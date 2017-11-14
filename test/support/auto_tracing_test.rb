# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class AutoTraceTest  < Minitest::Test
  def setup
    @tm = AppOptics::Config[:tracing_mode]
  end

  def teardown
    AppOptics::Config[:tracing_mode] = @tm
  end

  def test_trace_when_default_tm_dj
    AppOptics::API.start_trace('delayed_job-worker') do
      AppOptics.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_sidekiq
    AppOptics::API.start_trace('sidekiq-worker') do
      AppOptics.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_resque
    AppOptics::API.start_trace('resque-worker') do
      AppOptics.tracing?.must_equal true
    end
  end

  def test_trace_when_default_tm_rabbitmq
    AppOptics::API.start_trace('rabbitmq-consumer') do
      AppOptics.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    AppOptics::Config[:tracing_mode] = :never

    AppOptics::API.start_trace('delayed_job-worker') do
      AppOptics.tracing?.must_equal false
    end

    AppOptics::API.start_trace('asdf') do
      AppOptics.tracing?.must_equal false
    end
  end
end
