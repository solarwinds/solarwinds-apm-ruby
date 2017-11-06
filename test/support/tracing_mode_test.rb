# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    @tm = AppOptics::Config[:tracing_mode]
    AppOptics::Config[:tracing_mode] = :always
  end

  def teardown
    AppOptics::Config[:tracing_mode] = @tm
  end

  def test_trace_when_always
    AppOptics::API.start_trace(:test_always) do
      AppOptics.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    AppOptics::Config[:tracing_mode] = :never

    AppOptics::API.start_trace(:test_never) do
      AppOptics.tracing?.must_equal false
    end

    AppOptics::API.start_trace('asdf') do
      AppOptics.tracing?.must_equal false
    end
  end
end
