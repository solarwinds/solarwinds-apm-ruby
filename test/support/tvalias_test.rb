# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsAPM aliases' do # < Minitest::Test

  it 'responds to various capitalization' do
    _(defined?(::SolarWindsAPM)).must_equal "constant"
    _(defined?(::SolarWindsAPM)).must_equal "constant"
    _(defined?(::SolarWindsAPM)).must_equal "constant"
    _(defined?(::SolarWindsAPM)).must_equal "constant"

    _(SolarWindsAPM.methods.count).must_equal SolarWindsAPM.methods.count
    _(SolarWindsAPM.methods.count).must_equal SolarWindsAPM.methods.count
    _(SolarWindsAPM.methods.count).must_equal SolarWindsAPM.methods.count
  end
end

