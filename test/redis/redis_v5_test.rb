# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

if defined?(::Redis)
  describe "Redis Version 5 Test" do
    attr_reader :entry_kvs, :exit_kvs, :redis, :redis_version

    before do
      sleep 2
      @redis.flushall if defined? @redis
      @redis ||= Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                           :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

      @redis_version ||= @redis.info["redis_version"]

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
      @exit_kvs  ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }

      clear_all_traces

    end

  end
end
