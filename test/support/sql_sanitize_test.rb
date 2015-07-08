# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class SQLSanitizeTest < Minitest::Test
  def test_mysql_sanitize_1
    TraceView::Config[:sanitize_sql] = true

    sql = "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (19231, 3, 'cat', 'dog', 111.0, 126.0, 116.0, 79.0, 72.0, 73.0, ?, 1, 3, 229.284, ?, ?, 100, ?, 0, 3, 1, ?, NULL, NULL, ?, 4, ?)"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  end
end

