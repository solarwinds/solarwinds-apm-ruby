# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class APPOPTICSAliasTest < Minitest::Test

  def test_responds_various_capitalization
    defined?(::AppOptics).must_equal "constant"
    defined?(::AppOptics).must_equal "constant"

    AppOptics.methods.count.must_equal AppOptics.methods.count
  end
end

