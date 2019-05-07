# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SQLSanitizeTest' do 

  before do
    AppOpticsAPM::Config[:sanitize_sql] = false
  end

  it 'sanitizes an insert list' do
    AppOpticsAPM::Config[:sanitize_sql] = true

    sql = "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (19231, 3, 'cat', 'dog', 111.0, 126.0, 116.0, 79.0, 72.0, 73.0, ?, 1, 3, 229.284, ?, ?, 100, ?, 0, 3, 1, ?, NULL, NULL, ?, 4, ?)"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "INSERT INTO `queries` (`asdf_id`, `asdf_prices`, `created_at`, `updated_at`, `blue_pill`, `yearly_tax`, `rate`, `steam_id`, `red_pill`, `dimitri`, `origin`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  end

  it 'sanitizes a in list' do
    AppOpticsAPM::Config[:sanitize_sql] = true

    sql = "SELECT \"game_types\".* FROM \"game_types\" WHERE \"game_types\".\"game_id\" IN (1162)"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT \"game_types\".* FROM \"game_types\" WHERE \"game_types\".\"game_id\" IN (?)"
  end

  it 'sanitizes args in string' do
    AppOpticsAPM::Config[:sanitize_sql] = true

    sql = "SELECT \"comments\".* FROM \"comments\" WHERE \"comments\".\"commentable_id\" = 2798 AND \"comments\".\"commentable_type\" = 'Video' AND \"comments\".\"parent_id\" IS NULL ORDER BY comments.created_at DESC"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT \"comments\".* FROM \"comments\" WHERE \"comments\".\"commentable_id\" = ? AND \"comments\".\"commentable_type\" = ? AND \"comments\".\"parent_id\" IS ? ORDER BY comments.created_at DESC"
  end

  it 'sanitizes a mixture of situations' do
    AppOpticsAPM::Config[:sanitize_sql] = true

    sql = "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN (?) AND (updated_at >= ?) AND (updated_at <= ?) LIMIT ? OFFSET ?"
  end

  it 'sanitizes quoted stuff' do
    AppOpticsAPM::Config[:sanitize_sql] = true

    sql = "SELECT `users`.* FROM `users` WHERE (mobile IN ('234 234 234') AND email IN ('a_b_c@hotmail.co.uk'))"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT `users`.* FROM `users` WHERE (mobile IN (?) AND email IN (?))"
  end

  it 'sanitizes complicated quoted stuff' do
    AppOpticsAPM::Config[:sanitize_sql] = true


    # trying to reproduce "SELECT `users`.* FROM `users` WHERE (mobile IN (?a_b_c@hotmail.co.uk') LIMIT ?"
    sql = "SELECT `users`.* FROM `users` WHERE (mobile IN ('\\\'1454545') AND email IN ('a_b_c@hotmail.co.uk')) LIMIT 5"
    # sql = "SELECT `users`.* FROM `users` WHERE (mobile IN ('2342423') AND email IN ('a_b_c@hotmail.co.uk')) LIMIT 5"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT `users`.* FROM `users` WHERE (mobile IN (?) AND email IN (?)) LIMIT ?"
  end

  it 'does not sanitize when config is false' do
    AppOpticsAPM::Config[:sanitize_sql] = false

    sql = "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
    result = AppOpticsAPM::Util.sanitize_sql(sql)
    result.must_equal "SELECT `assets`.* FROM `assets` WHERE `assets`.`type` IN ('Picture') AND (updated_at >= '2015-07-08 19:22:00') AND (updated_at <= '2015-07-08 19:23:00') LIMIT 31 OFFSET 0"
  end
end

