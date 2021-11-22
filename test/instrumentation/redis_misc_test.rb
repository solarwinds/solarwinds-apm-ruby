# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

if defined?(::Redis)
  describe "Redis Misc" do
    attr_reader :entry_kvs, :exit_kvs, :redis, :redis_version

    def min_server_version(version)
      unless Gem::Version.new(@redis_version) >= Gem::Version.new(version.to_s)
        skip "supported only on redis-server #{version} or greater"
      end
    end

    before do
      clear_all_traces

      @redis ||= Redis.new(:host => ENV['REDIS_HOST'] || ENV['APPOPTICS_REDIS_SERVER'] || '127.0.0.1',
                           :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

      @redis_version ||= @redis.info["redis_version"]

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
      @exit_kvs  ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
    end

    it "should trace auth and not include password" do

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.auth(ENV['REDIS_PASSWORD'] || 'secret_pass')
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "auth"
      _(traces[2].has_key?('KVKey')).must_equal false
    end

    it "should trace publish" do
      min_server_version(2.0)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.publish("channel1", "Broadcasting live from silicon circuits.")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "publish"
      _(traces[2]['channel']).must_equal "channel1"
      _(traces[2].has_key?('KVKey')).must_equal false
    end

    it "should trace select" do
      min_server_version(2.0)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.select(2)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "select"
      _(traces[2]['db']).must_equal 2
    end

    it "should trace pipelined operations" do
      min_server_version(1.2)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.pipelined do
          @redis.zadd("staff", 0, "waiter")
          @redis.zadd("staff", 1, "busser")
          @redis.zadd("staff", 2, "chef")

          @redis.lpush("fringe", "bishop")
          @redis.lpush("fringe", "dunham")
          @redis.lpush("fringe", "broyles")
        end
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOpCount']).must_equal 6
      _(traces[2]['KVOps']).must_equal "zadd, zadd, zadd, lpush, lpush, lpush"
    end

    it "should trace multi with block" do
      min_server_version(1.2)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.multi do
          @redis.zadd("presidents", 0, "Lincoln")
          @redis.zadd("presidents", 1, "Adams")
          @redis.zadd("presidents", 2, "Reagan")

          @redis.lpush("hair", "blue")
          @redis.lpush("hair", "gray")
          @redis.lpush("hair", "yellow")
        end
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOpCount']).must_equal 8
      _(traces[2]['KVOps']).must_equal "multi, zadd, zadd, zadd, lpush, lpush, lpush, exec"
    end

    it "should trace eval" do
      min_server_version(2.6)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.eval("return 1")
        @redis.eval("return { KEYS, ARGV }", ["k1", "k2"], ["a1", "a2"])
        @redis.eval("return { KEYS, ARGV }", :keys => ["k1", "k2"], :argv => ["a1", "a2"])
      end

      traces = get_all_traces
      _(traces.count).must_equal 8
      _(traces[2]['KVOp']).must_equal "eval"
      _(traces[2]['Script']).must_equal "return 1"
      _(traces[4]['KVOp']).must_equal "eval"
      _(traces[4]['Script']).must_equal "return { KEYS, ARGV }"
      _(traces[6]['KVOp']).must_equal "eval"
      _(traces[6]['Script']).must_equal "return { KEYS, ARGV }"
    end

    it "should trace evalsha" do
      min_server_version(2.6)

      sha = @redis.script(:load, "return 1")

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @redis.evalsha(sha)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "evalsha"
      _(traces[2]['sha']).must_equal sha
    end

    it "should trace script" do
      min_server_version(2.6)

      AppOpticsAPM::SDK.start_trace('redis_test', {}) do
        @sha = @redis.script(:load, "return 1")
        @it_exists1 = @redis.script(:exists, @sha)
        @it_exists2 = @redis.script(:exists, [@sha, "other_sha"])
        @redis.script(:flush)
      end

      traces = get_all_traces
      _(traces.count).must_equal 10

      # Validate return values
      _(@it_exists1).must_equal true
      _(@it_exists2.is_a?(Array)).must_equal true
      _(@it_exists2[0]).must_equal true
      _(@it_exists2[1]).must_equal false

      _(traces[2]['KVOp']).must_equal "script"
      _(traces[2]['subcommand']).must_equal "load"
      _(traces[2]['Script']).must_equal "return 1"
      _(traces[4]['KVOp']).must_equal "script"
      _(traces[4]['subcommand']).must_equal "exists"
      _(traces[4]['KVKey']).must_equal @sha
      _(traces[6]['KVOp']).must_equal "script"
      _(traces[6]['subcommand']).must_equal "exists"
      _(traces[6]['KVKey']).must_equal '["e0e1f9fabfc9d4800c877a703b823ac0578ff8db", "other_sha"]'
      _(traces[8]['KVOp']).must_equal "script"
      _(traces[8]['subcommand']).must_equal "flush"
    end
  end
end
