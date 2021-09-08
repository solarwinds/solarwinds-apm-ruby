# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "TracingModeTest" do
  def setup
    @tm = AppOpticsAPM::Config[:tracing_mode]
    @config_url_disabled = AppOpticsAPM::Config[:url_disabled_regexps]
    @config_url_enabled = AppOpticsAPM::Config[:url_enabled_regexps]

    AppOpticsAPM::Config[:url_disabled_regexps] = nil
    AppOpticsAPM::Config[:url_enabled_regexps] = nil
  end

  def teardown
    AppOpticsAPM::Config[:tracing_mode] = @tmo
    AppOpticsAPM::Config[:url_disabled_regexps] = @config_url_disabled
    AppOpticsAPM::Config[:url_enabled_regexps] =  @config_url_enabled
  end

  def test_trace_when_enabled
    AppOpticsAPM::Config[:tracing_mode] = :enabled

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
