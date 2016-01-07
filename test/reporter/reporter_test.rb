# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class TVReporterTest < Minitest::Test
  def reporter_has_start_method
    assert_equal true, TV::Reporter.respond_to?(:start), "has restart method"
  end

  def reporter_has_restart_method
    assert_equal true, TV::Reporter.respond_to?(:restart), "has start method"
  end
end
