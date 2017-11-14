# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class APPOPTICSReporterTest < Minitest::Test
  def reporter_has_start_method
    assert_equal true, AppOptics::Reporter.respond_to?(:start), "has restart method"
  end

  def reporter_has_restart_method
    assert_equal true, AppOptics::Reporter.respond_to?(:restart), "has start method"
  end
end
