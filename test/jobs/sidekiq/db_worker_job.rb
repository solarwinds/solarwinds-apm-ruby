# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

class DBWorkerJob
  include Sidekiq::Worker

  def perform(*args)
    return unless defined?(::Sequel) && !defined?(JRUBY_VERSION)

    if ENV.key?('TRAVIS_MYSQL_PASS')
      @db = Sequel.connect("mysql2://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/test_db")
    else
      @db = Sequel.connect('mysql2://root@127.0.0.1:3306/test_db')
    end

    unless @db.table_exists?(:items)
      @db.create_table :items do
        primary_key :id
        String :name
        Float :price
      end
    end

    @db.run('select 1')

    items = @db[:items]
    items.count
  end
end
