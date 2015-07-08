# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class SQLSanitizeTest < Minitest::Test
  def setup
    @sanitize_sql = TraceView::Config[:sanitize_sql]
  end

  def teardown
    TraceView::Config[:sanitize_sql] = @sanitize_sql
  end

  def test_sanitize_sql1
    TraceView::Config[:sanitize_sql] = true

    sql = "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (19231, 3, 'cat', 'dog', 111.0, 126.0, 116.0, 79.0, 72.0, 73.0, ?, 1, 3, 229.284, ?, ?, 100, ?, 0, 3, 1, ?, NULL, NULL, ?, 4, ?)"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  end

  def test_sanitize_sql2
    TraceView::Config[:sanitize_sql] = true

    sql = "SELECT \"game_types\".* FROM \"game_types\" WHERE \"game_types\".\"game_id\" IN (1162)"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "SELECT \"game_types\".* FROM \"game_types\" WHERE \"game_types\".\"game_id\" IN (?)"
  end

  def test_sanitize_sql3
    TraceView::Config[:sanitize_sql] = true

    sql = "SELECT \"comments\".* FROM \"comments\" WHERE \"comments\".\"commentable_id\" = 2798 AND \"comments\".\"commentable_type\" = 'Video' AND \"comments\".\"parent_id\" IS NULL ORDER BY comments.created_at DESC"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "SELECT \"comments\".* FROM \"comments\" WHERE \"comments\".\"commentable_id\" = ? AND \"comments\".\"commentable_type\" = ? AND \"comments\".\"parent_id\" IS ? ORDER BY comments.created_at DESC"
  end

  def test_sanitize_sql4
    TraceView::Config[:sanitize_sql] = true

    sql = "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN (?) AND (updated_at >= ?) AND (updated_at <= ?) LIMIT ? OFFSET ?"
  end

  def test_dont_sanitize
    TraceView::Config[:sanitize_sql] = false

    sql = "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
    result = TraceView::Util.sanitize_sql(sql)
    result.must_equal "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
  end
end

