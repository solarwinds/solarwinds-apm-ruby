# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class InitReportTest  < Minitest::Test
  def test_report_format
    init_kvs = ::TraceView::Util.build_init_report
    init_kvs.is_a?(Hash)
  end

  def test_report_kvs
    init_kvs = ::TraceView::Util.build_init_report
    init_kvs.has_key?("__Init").must_equal true
    init_kvs.has_key?("Force").must_equal true
    init_kvs.has_key?("Ruby.AppContainer.Version").must_equal true
    init_kvs["Ruby.TraceView.Version"].must_equal TraceView::Version::STRING
    init_kvs["Ruby.TraceMode.Version"].must_equal TraceView::Config[:tracing_mode]
  end

  def test_legacy_report_format
    init_kvs = ::TraceView::Util.legacy_build_init_report
    init_kvs.is_a?(Hash)
  end
end
