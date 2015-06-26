# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

if defined?(::Redis)
  describe "Redis Hashes" do
    attr_reader :entry_kvs, :exit_kvs, :redis, :redis_version

    def min_server_version(version)
      unless Gem::Version.new(@redis_version) >= Gem::Version.new(version.to_s)
        skip "supported only on redis-server #{version} or greater"
      end
    end

    before do
      clear_all_traces

      @redis ||= Redis.new

      @redis_version ||= @redis.info["redis_version"]

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
      @exit_kvs  ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
    end

    it 'Stock Redis should be loaded, defined and ready' do
      defined?(::Redis).wont_match nil
    end

    it "should trace hdel" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hdel("whale", "color")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hdel"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['field'].must_equal "color"
    end

    it "should trace hdel multiple fields" do
      min_server_version(2.4)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hdel("whale", ["color", "eyes"])
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hdel"
      traces[2]['KVKey'].must_equal "whale"
      traces[2].has_key?('field').must_equal false
    end

    it "should trace hexists" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hexists("whale", "color")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hexists"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['field'].must_equal "color"
    end

    it "should trace hget" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hget("whale", "color")
        @redis.hget("whale", "noexist")
      end

      traces = get_all_traces
      traces.count.must_equal 6
      traces[2]['KVOp'].must_equal "hget"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['KVHit'].must_equal 1
      traces[2]['field'].must_equal "color"
      traces[4]['KVHit'].must_equal 0
    end

    it "should trace hgetall" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hgetall("whale")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hgetall"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hincrby" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hincrby("whale", "age", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hincrby"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['field'].must_equal "age"
      traces[2]['increment'].must_equal 1
    end

    it "should trace hincrbyfloat" do
      min_server_version(2.6)

      @redis.hset("whale", "age", 32)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hincrbyfloat("whale", "age", 1.3)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hincrbyfloat"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['field'].must_equal "age"
      traces[2]['increment'].must_equal 1.3
    end

    it "should trace hkeys" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hkeys("whale")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hkeys"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hlen" do
      min_server_version(2.0)

      @redis.hset("whale", "age", 32)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hlen("whale")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hlen"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hmget" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hmget("whale", "color", "size", "blah", "brown")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hmget"
      traces[2]['KVKey'].must_equal "whale"
      traces[2]['KVKeyCount'].must_equal 4
      traces[2]['KVHitCount'].must_equal 2
    end

    it "should trace hmset" do
      min_server_version(2.0)

      @redis.hset("whale", "color", "blue")
      @redis.hset("whale", "size", "big")
      @redis.hset("whale", "eyes", "green")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hmset("whale", ["color", "red", "size", "very big"])
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hmset"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hset" do
      min_server_version(2.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hset("whale", "eyes", "green")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hset"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hsetnx" do
      min_server_version(2.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hsetnx("whale", "eyes", "green")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hsetnx"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hvals" do
      min_server_version(2.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hvals("whale")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hvals"
      traces[2]['KVKey'].must_equal "whale"
    end

    it "should trace hscan" do
      min_server_version(2.8)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.hscan("whale", 0)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "hscan"
      traces[2]['KVKey'].must_equal "whale"
    end
  end
end
