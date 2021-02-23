# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'InitReportTest' do
   it 'report_format' do
    init_kvs = ::AppOpticsAPM::Util.build_init_report
    init_kvs.is_a?(Hash)
  end

   it 'report_kvs' do
    init_kvs = ::AppOpticsAPM::Util.build_init_report
    _(init_kvs.has_key?("__Init")).must_equal true
    _(init_kvs.has_key?("Force")).must_equal true
    _(init_kvs.has_key?("Ruby.AppContainer.Version")).must_equal true
    _(init_kvs["Ruby.AppOptics.Version"]).must_equal AppOpticsAPM::Version::STRING
    _(init_kvs["Ruby.AppOpticsExtension.Version"]).must_equal File.read(clib_version_file).chomp
    _(init_kvs["Ruby.TraceMode.Version"]).must_equal AppOpticsAPM::Config[:tracing_mode]
  end

  # @deprecated
   it 'legacy_report_format' do
    init_kvs = ::AppOpticsAPM::Util.legacy_build_init_report
    init_kvs.is_a?(Hash)
  end
end
