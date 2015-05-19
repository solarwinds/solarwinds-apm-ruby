require 'minitest_helper'

if defined?(::Redis)
  describe Oboe::Inst::Redis, :strings do
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

    it "should trace append" do
      @redis.set("yourkey", "test")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.append("yourkey", "blah")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "append"
      traces[2]['KVKey'].must_equal "yourkey"
    end

    it "should trace bitcount (>=2.6)" do

      min_server_version("2.6")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.bitcount("yourkey")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "bitcount"
      traces[2]['start'].must_equal 0
      traces[2]['stop'].must_equal -1
    end

    it "should trace bitop (>=2.6)" do

      min_server_version("2.6")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.bitop("not", "bitopkey", "yourkey")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "bitop"
      traces[2]['operation'].must_equal "not"
      traces[2]['destkey'].must_equal "bitopkey"
    end

    it "should trace decr" do
      @redis.setex("decr", 60, 0)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.decr("decr")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "decr"
      traces[2]['KVKey'].must_equal "decr"
    end

    it "should trace decrby" do
      @redis.setex("decr", 60, 0)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.decrby("decr", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "decrby"
      traces[2]['KVKey'].must_equal "decr"
      traces[2]['decrement'].must_equal 1
    end

    it "should trace get" do
      @redis.setex("diwore", 60, "okokok")

      Oboe::API.start_trace('redis_test', '', {}) do
        @rv = @redis.get("diwore")
      end

      @rv.must_equal "okokok"

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "get"
      traces[2]['KVKey'].must_equal "diwore"
    end

    it "should trace getbit" do
      min_server_version(2.2)

      @redis.setex("diwore", 60, "okokok")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.getbit("diwore", 3)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "getbit"
      traces[2]['KVKey'].must_equal "diwore"
      traces[2]['offset'].must_equal 3
    end

    it "should trace getrange" do
      min_server_version(2.2)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.getrange("yourkey", 0, 3)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "getrange"
      traces[2]['KVKey'].must_equal "yourkey"
      traces[2]['start'].must_equal 0
      traces[2]['end'].must_equal 3
    end

    it "should trace getset" do
      min_server_version(2.2)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.getset("dollar", 0)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "getset"
      traces[2]['KVKey'].must_equal "dollar"
      traces[2]['value'].must_equal "0"
    end

    it "should trace incr" do
      @redis.setex("dotcom", 60, 0)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.incr("dotcom")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "incr"
      traces[2]['KVKey'].must_equal "dotcom"
    end

    it "should trace incrby" do
      @redis.setex("incr", 60, 0)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.incrby("incr", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "incrby"
      traces[2]['KVKey'].must_equal "incr"
      traces[2]['increment'].must_equal 1
    end

    it "should trace incrbyfloat" do
      min_server_version(2.6)

      @redis.setex("incrfloat", 60, 0.0)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.incrbyfloat("incrfloat", 1.01)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "incrbyfloat"
      traces[2]['KVKey'].must_equal "incrfloat"
      traces[2]['increment'].must_equal 1.01
    end

    it "should trace mget" do
      @redis.setex("france", 60, "ok")
      @redis.setex("denmark", 60, "ok")
      @redis.setex("germany", 60, "ok")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.mget(["france", "nothing", "denmark"])
        @redis.mget("germany")
      end

      traces = get_all_traces
      traces.count.must_equal 6
      traces[2]['KVOp'].must_equal "mget"
      traces[2]['KVKeyCount'].must_equal 3
      traces[2]['KVHitCount'].must_equal 2
      traces[4]['KVOp'].must_equal "mget"
      traces[4]['KVKeyCount'].must_equal 1
      traces[4]['KVHitCount'].must_equal 1
    end

    it "should trace mset" do
      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.mset(["one", 1, "two", 2, "three", 3])
        @redis.mset("one", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 6
      traces[2]['KVOp'].must_equal "mset"
      traces[2]['KVKeyCount'].must_equal 3
      traces[4]['KVOp'].must_equal "mset"
      traces[4]['KVKeyCount'].must_equal 1
    end

    it "should trace msetnx" do
      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.msetnx(["one", 1, "two", 2, "three", 3])
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "msetnx"
    end

    it "should trace psetex (>= v2.6)" do

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.psetex("one", 60, "hello")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "psetex"
      traces[2]['KVKey'].must_equal "one"
      traces[2]['ttl'].must_equal 60
    end

    it "should trace basic set" do
      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.set("one",   "hello")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "set"
      traces[2]['KVKey'].must_equal "one"
    end

    it "should trace setbit" do
      min_server_version(2.2)

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.setbit("yourkey", 3, 0)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "setbit"
      traces[2]['KVKey'].must_equal "yourkey"
      traces[2]['offset'].must_equal 3
    end

    it "should trace setex" do
      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.setex("one", 60, "hello")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "setex"
      traces[2]['KVKey'].must_equal "one"
      traces[2]['ttl'].must_equal 60
    end

    it "should trace setnx" do
      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.setnx("one", "hello")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "setnx"
      traces[2]['KVKey'].must_equal "one"
    end

    it "should trace setrange" do
      min_server_version(2.2)

      @redis.setex("spandau_ballet", 60, "XXXXXXXXXXXXXXX")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.setrange("yourkey", 2, "ok")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "setrange"
      traces[2]['KVKey'].must_equal "yourkey"
      traces[2]['offset'].must_equal 2
    end

    it "should trace strlen" do
      min_server_version(2.2)

      @redis.setex("talking_heads", 60, "burning down the house")

      Oboe::API.start_trace('redis_test', '', {}) do
        @redis.strlen("talking_heads")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "strlen"
      traces[2]['KVKey'].must_equal "talking_heads"
    end
  end
end
