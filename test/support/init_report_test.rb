# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'InitReportTest' do

  it 'report_format' do
    init_kvs = ::SolarWindsAPM::Util.build_init_report
    init_kvs.is_a?(Hash)
  end

  it 'report_kvs' do
    init_kvs = ::SolarWindsAPM::Util.build_init_report

    _(init_kvs.has_key?("__Init")).must_equal true
    _(init_kvs.has_key?("process.pid")).must_equal true
    _(init_kvs.has_key?("process.command")).must_equal true
    _(init_kvs.has_key?("process.runtime.name")).must_equal true
    _(init_kvs.has_key?("process.runtime.version")).must_equal true
    _(init_kvs.has_key?("process.runtime.description")).must_equal true
    _(init_kvs.has_key?("process.command")).must_equal true

    _(init_kvs["__Init"]).must_equal true
    _(init_kvs["APM.Version"]).must_equal SolarWindsAPM::Version::STRING
    _(init_kvs["APM.Extension.Version"]).must_equal Oboe_metal::Config.getVersionString
    _(init_kvs["telemetry.sdk.language"]).must_equal "ruby"
  end
end
