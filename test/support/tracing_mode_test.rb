# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "TracingModeTest" do
  def setup
    @tm = SolarWindsAPM::Config[:tracing_mode]
    @config_url_disabled = SolarWindsAPM::Config[:url_disabled_regexps]
    @config_url_enabled = SolarWindsAPM::Config[:url_enabled_regexps]

    SolarWindsAPM::Config[:url_disabled_regexps] = nil
    SolarWindsAPM::Config[:url_enabled_regexps] = nil
  end

  def teardown
    SolarWindsAPM::Config[:tracing_mode] = @tm
    SolarWindsAPM::Config[:url_disabled_regexps] = @config_url_disabled
    SolarWindsAPM::Config[:url_enabled_regexps] =  @config_url_enabled
  end

  def test_trace_when_enabled
    SolarWindsAPM::Config[:tracing_mode] = :enabled

    SolarWindsAPM::SDK.start_trace(:test_enabled) do
      _(SolarWindsAPM.tracing?).must_equal true
    end
  end

  def test_dont_trace_when_disabled
    SolarWindsAPM::Config[:tracing_mode] = :disabled

    SolarWindsAPM::SDK.start_trace(:test_disabled) do
      # TODO FLAKY
      _(SolarWindsAPM.tracing?).must_equal false, "flaky test"
    end

    SolarWindsAPM::SDK.start_trace('asdf') do
      _(SolarWindsAPM.tracing?).must_equal false
    end
  end
end
