require 'minitest_helper'
require "redis"
    
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
    traces[1]['KVOp'].must_equal "append"
    traces[1]['KVKey'].must_equal "yourkey"
  end
  
  it "should trace bitcount (>=2.6)" do
    
    min_server_version("2.6")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.bitcount("yourkey")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "bitcount"
    traces[1]['start'].must_equal "0"
    traces[1]['stop'].must_equal "-1"
  end
  
  it "should trace bitop (>=2.6)" do
    
    min_server_version("2.6")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.bitop("not", "bitopkey", "yourkey")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "bitop"
    traces[1]['operation'].must_equal "not"
    traces[1]['destkey'].must_equal "bitopkey"
  end
  
  it "should trace decr" do
    @redis.setex("decr", 60, 0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.decr("decr")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "decr"
    traces[1]['KVKey'].must_equal "decr"
  end
  
  it "should trace decrby" do
    @redis.setex("decr", 60, 0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.decrby("decr", 1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "decrby"
    traces[1]['KVKey'].must_equal "decr"
    traces[1]['decrement'].must_equal "1"
  end
  
  it "should trace get" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.get("yourkey")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "get"
    traces[1]['KVKey'].must_equal "yourkey"
  end
  
  it "should trace getbit" do
    min_server_version(2.2)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.getbit("yourkey", 3)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "getbit"
    traces[1]['KVKey'].must_equal "yourkey"
    traces[1]['offset'].must_equal "3"
  end
  
  it "should trace getrange" do
    min_server_version(2.2)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.getrange("yourkey", 0, 3)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "getrange"
    traces[1]['KVKey'].must_equal "yourkey"
    traces[1]['start'].must_equal "0"
    traces[1]['end'].must_equal "3"
  end
  
  it "should trace getset" do
    min_server_version(2.2)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.getset("dollar", 0)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "getset"
    traces[1]['KVKey'].must_equal "dollar"
    traces[1]['value'].must_equal "0"
  end
  
  it "should trace incr" do
    @redis.setex("dotcom", 60, 0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.incr("dotcom")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "incr"
    traces[1]['KVKey'].must_equal "dotcom"
  end

  it "should trace incrby" do
    @redis.setex("incr", 60, 0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.incrby("incr", 1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "incrby"
    traces[1]['KVKey'].must_equal "incr"
    traces[1]['increment'].must_equal "1"
  end
  
  it "should trace incrbyfloat" do
    min_server_version(2.6)

    @redis.setex("incrfloat", 60, 0.0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.incrbyfloat("incrfloat", 1.01)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "incrbyfloat"
    traces[1]['KVKey'].must_equal "incrfloat"
    traces[1]['increment'].must_equal "1.01"
  end
  
  it "should trace mget" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.mget(["one", "two", "three"])
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "mget"
  end
  
  it "should trace mset" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.mset(["one", 1, "two", 2, "three", 3])
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "mset"
  end
  
  it "should trace msetnx" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.msetnx(["one", 1, "two", 2, "three", 3])
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "msetnx"
  end
  
  it "should trace psetex (>= v2.6)" do
    unless (@redis.info["redis_version"] =~ /2.6/) == 0
      skip "supported only redis-server 2.6.0" 
    end

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.psetex("one", 60, "hello")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "psetex"
    traces[1]['KVKey'].must_equal "one"
    traces[1]['ttl'].must_equal "60"
  end
  
  it "should trace basic set" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.set("one",   "hello")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "set"
    traces[1]['KVKey'].must_equal "one"
  end
  
  it "should trace set with options hash (>= v2.6)" do
    min_server_version(2.6)
    unless (@redis.info["redis_version"] =~ /2.6/) == 0
      skip "supported only redis-server 2.6.0" 
    end

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.set("one",   "hello")
      @redis.set("two",   "hello", { :ex => 60 })
      @redis.set("three", "hello", { :px => 1000 })
      @redis.set("four",  "hello", { :nx => true })
      @redis.set("five",  "hello", { :xx => true })
    end
    
    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "set"
    traces[1]['KVKey'].must_equal "one"
    traces[3]['KVKey'].must_equal "two"
    traces[3]['EX'].must_equal "60"
    traces[5]['KVKey'].must_equal "three"
    traces[5]['PX'].must_equal "1000"
    traces[7]['KVKey'].must_equal "four"
    traces[7]['NX'].must_equal "true"
    traces[9]['KVKey'].must_equal "five"
    traces[9]['XX'].must_equal "true"
  end

  it "should trace setbit" do
    min_server_version(2.2)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.setbit("yourkey", 3, 0)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "setbit"
    traces[1]['KVKey'].must_equal "yourkey"
    traces[1]['offset'].must_equal "3"
  end
  
  it "should trace setex" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.setex("one", 60, "hello")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "setex"
    traces[1]['KVKey'].must_equal "one"
    traces[1]['ttl'].must_equal "60"
  end

  it "should trace setnx" do
    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.setnx("one", "hello")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "setnx"
    traces[1]['KVKey'].must_equal "one"
  end
  
  it "should trace setrange" do
    min_server_version(2.2)

    @redis.setex("spandau_ballet", 60, "XXXXXXXXXXXXXXX")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.setrange("yourkey", 2, "ok")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "setrange"
    traces[1]['KVKey'].must_equal "yourkey"
    traces[1]['offset'].must_equal "2"
  end

  it "should trace strlen" do
    min_server_version(2.2)

    @redis.setex("talking_heads", 60, "burning down the house")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.strlen("talking_heads")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "strlen"
    traces[1]['KVKey'].must_equal "talking_heads"
  end
end
