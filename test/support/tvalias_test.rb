# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'AppOpticsAPM aliases' do # < Minitest::Test

  it 'responds to various capitalization' do
    _(defined?(::AppOpticsAPM)).must_equal "constant"
    _(defined?(::AppopticsAPM)).must_equal "constant"
    _(defined?(::AppOpticsApm)).must_equal "constant"
    _(defined?(::AppopticsApm)).must_equal "constant"

    _(AppopticsAPM.methods.count).must_equal AppOpticsAPM.methods.count
    _(AppOpticsApm.methods.count).must_equal AppOpticsAPM.methods.count
    _(AppopticsApm.methods.count).must_equal AppOpticsAPM.methods.count
  end
end

