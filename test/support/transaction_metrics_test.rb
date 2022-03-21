# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'TransactionSettingsTest' do
  before do
    @tracing_mode = SolarWindsAPM::Config[:tracing_mode]
    @sample_rate = SolarWindsAPM::Config[:sample_rate]
    @config_map = SolarWindsAPM::Util.deep_dup(SolarWindsAPM::Config[:transaction_settings])
    @config_url_disabled = SolarWindsAPM::Config[:url_disabled_regexps]
  end

  after do
    SolarWindsAPM::Config[:transaction_settings] = SolarWindsAPM::Util.deep_dup(@config_map)
    SolarWindsAPM::Config[:url_disabled_regexps] = @config_url_disabled
    SolarWindsAPM::Config[:tracing_mode] = @tracing_mode
    SolarWindsAPM::Config[:sample_rate] = @sample_rate
  end

  describe 'metrics' do
    it 'obeys do_metrics false' do
      SolarWindsAPM::TransactionMetrics.expects(:send_metrics).never
      SolarWindsAPM.expects(:transaction_name=).never

      settings = SolarWindsAPM::TransactionSettings.new
      settings.do_sample = false
      settings.do_metrics = false

      yielded = false

      SolarWindsAPM::TransactionMetrics.metrics({}, settings) { yielded = true }
      assert yielded
    end

    it 'obeys do_metrics true' do
      SolarWindsAPM::TransactionMetrics.expects(:send_metrics).returns('name')
      SolarWindsAPM.expects(:transaction_name=).with('name')

      settings = SolarWindsAPM::TransactionSettings.new
      settings.do_sample = true
      settings.do_metrics = true

      yielded = false

      SolarWindsAPM::TransactionMetrics.metrics({}, settings) { yielded = true }
      assert yielded
    end

    it 'sends metrics when there is an error' do
      SolarWindsAPM::TransactionMetrics.expects(:send_metrics).returns('name')
      SolarWindsAPM.expects(:transaction_name=).with('name')

      settings = SolarWindsAPM::TransactionSettings.new
      settings.do_sample = true
      settings.do_metrics = true
      begin
        SolarWindsAPM::TransactionMetrics.metrics({}, settings) { raise StandardError }
      rescue
      end
    end
  end
end
