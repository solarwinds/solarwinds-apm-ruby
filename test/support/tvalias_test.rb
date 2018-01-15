# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class APPOPTICSAliasTest < Minitest::Test

  def test_responds_various_capitalization
    defined?(::AppOpticsAPM).must_equal "constant"
    defined?(::AppOpticsAPM).must_equal "constant"

    AppOpticsAPM.methods.count.must_equal AppOpticsAPM.methods.count
  end
end

