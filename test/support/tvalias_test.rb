# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'AppOpticsAPM aliases' do # < Minitest::Test

  it 'responds to various capitalization' do
    defined?(::AppOpticsAPM).must_equal "constant"
    defined?(::AppopticsAPM).must_equal "constant"
    defined?(::AppOpticsApm).must_equal "constant"
    defined?(::AppopticsApm).must_equal "constant"

    AppopticsAPM.methods.count.must_equal AppOpticsAPM.methods.count
    AppOpticsApm.methods.count.must_equal AppOpticsAPM.methods.count
    AppopticsApm.methods.count.must_equal AppOpticsAPM.methods.count
  end
end

