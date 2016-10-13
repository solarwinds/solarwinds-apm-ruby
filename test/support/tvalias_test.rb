# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TVAliasTest < Minitest::Test

  def test_responds_various_capitalization
    defined?(::TraceView).must_equal "constant"
    defined?(::Traceview).must_equal "constant"

    TraceView.methods.count.must_equal Traceview.methods.count
  end
end

