# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    @tm = AppOpticsAPM::Config[:tracing_mode]
    AppOpticsAPM::Config[:tracing_mode] = :always
  end

  def teardown
    AppOpticsAPM::Config[:tracing_mode] = @tm
  end

  def test_trace_when_always
    AppOpticsAPM::API.start_trace(:test_always) do
      AppOpticsAPM.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    AppOpticsAPM::Config[:tracing_mode] = :never

    AppOpticsAPM::API.start_trace(:test_never) do
      AppOpticsAPM.tracing?.must_equal false
    end

    AppOpticsAPM::API.start_trace('asdf') do
      AppOpticsAPM.tracing?.must_equal false
    end
  end
end
