# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

if defined?(::Redis)
  describe "Redis Hashes" do
    attr_reader :entry_kvs, :exit_kvs, :redis, :redis_version
    
    before do
      sleep 2
      @redis.flushall if defined? @redis
      send(:remove_instance_variable, :@redis) if defined? @redis

      @redis ||= Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                           :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

      @redis_version ||= @redis.info["redis_version"]

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
      @exit_kvs  ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
      clear_all_traces
    end

    it 'Stock Redis should be loaded, defined and ready' do
      _(defined?(::Redis)).wont_match nil
    end

    it "should trace hdel" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hdel("whale", "color")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hdel"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['field']).must_equal "color"
    end

    it "should trace hdel multiple fields" do
      min_server_version(2.4)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hdel("whale", ["color", "eyes"])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hdel"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2].has_key?('field')).must_equal false
    end

    it "should trace hexists" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hexists("whale", "color")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hexists"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['field']).must_equal "color"
    end

    it "should trace hget" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hget("whale", "color")
        @redis.hget("whale", "noexist")
      end

      traces = get_all_traces
      _(traces.count).must_equal 6, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hget"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['KVHit']).must_equal 1
      _(traces[2]['field']).must_equal "color"
      _(traces[4]['KVHit']).must_equal 0
    end

    it "should trace hgetall" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hgetall("whale")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hgetall"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hincrby" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hincrby("whale", "age", 1)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hincrby"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['field']).must_equal "age"
      _(traces[2]['increment']).must_equal "1"
    end

    it "should trace hincrbyfloat" do
      min_server_version(2.6)

      @redis.hset("whale", "age", 32)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hincrbyfloat("whale", "age", 1.3)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hincrbyfloat"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['field']).must_equal "age"
      _(traces[2]['increment']).must_equal "1.3"
    end

    it "should trace hkeys" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hkeys("whale")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hkeys"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hlen" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hlen("whale")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hlen"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hmget" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hmget("whale", "color", "size", "blah", "brown")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hmget"
      _(traces[2]['KVKey']).must_equal "whale"
      _(traces[2]['KVKeyCount']).must_equal 4
      _(traces[2]['KVHitCount']).must_equal 2
    end

    it "should trace hmset" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hmset("whale", ["color", "red", "size", "very big"])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hmset"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hset" do
      min_server_version(2.0)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hset("whale", "eyes", "green")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hset"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hsetnx" do
      min_server_version(2.0)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hsetnx("whale", "eyes", "green")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hsetnx"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hvals" do
      min_server_version(2.0)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hvals("whale")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hvals"
      _(traces[2]['KVKey']).must_equal "whale"
    end

    it "should trace hscan" do
      min_server_version(2.8)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.hscan("whale", 0)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect
      _(traces[2]['KVOp']).must_equal "hscan"
      _(traces[2]['KVKey']).must_equal "whale"
    end
  end
end
