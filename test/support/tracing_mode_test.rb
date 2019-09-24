# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    @tm = AppOpticsAPM::Config[:tracing_mode]
    AppOpticsAPM::Config[:tracing_mode] = :enabled
  end

  def teardown
    AppOpticsAPM::Config[:tracing_mode] = @tm
  end

  def test_trace_when_enabled
    AppOpticsAPM::API.start_trace(:test_enabled) do
      _(AppOpticsAPM.tracing?).must_equal true
    end
  end

  def test_dont_trace_when_disabled
    AppOpticsAPM::Config[:tracing_mode] = :disabled

    AppOpticsAPM::API.start_trace(:test_disabled) do
      _(AppOpticsAPM.tracing?).must_equal false
    end

    AppOpticsAPM::API.start_trace('asdf') do
      _(AppOpticsAPM.tracing?).must_equal false
    end
  end
end
