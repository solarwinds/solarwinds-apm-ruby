require 'minitest_helper'
require "redis"
    
describe Oboe::Inst::Redis, :sortedsets do
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

  it "should trace pipelined operations" do
    min_server_version(1.2)

    Oboe::API.start_trace('redis_test', '', {}) do
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
    traces.count.must_equal 4
    traces[2]['KVOpCount'].must_equal "6"
    traces[2]['KVOps'].must_equal "zadd, zadd, zadd, lpush, lpush, lpush"
  end
  
  it "should trace multi with block" do
    min_server_version(1.2)

    Oboe::API.start_trace('redis_test', '', {}) do
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
    traces.count.must_equal 4
    traces[2]['KVOpCount'].must_equal "8"
    traces[2]['KVOps'].must_equal "multi, zadd, zadd, zadd, lpush, lpush, lpush, exec"
  end
  
  it "should trace eval" do
    min_server_version(2.6)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.eval("return 1")
      @redis.eval("return { KEYS, ARGV }", ["k1", "k2"], ["a1", "a2"])
      @redis.eval("return { KEYS, ARGV }", :keys => ["k1", "k2"], :argv => ["a1", "a2"])
    end

    traces = get_all_traces
    traces.count.must_equal 8
    traces[2]['KVOp'].must_equal "eval"
    traces[2]['script'].must_equal "return 1"
    traces[4]['KVOp'].must_equal "eval"
    traces[4]['script'].must_equal "return { KEYS, ARGV }"
    traces[6]['KVOp'].must_equal "eval"
    traces[6]['script'].must_equal "return { KEYS, ARGV }"
  end
  
  it "should trace evalsha" do
    min_server_version(2.6)
      
    sha = @redis.script(:load, "return 1")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.evalsha(sha)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "evalsha"
    traces[2]['sha'].must_equal sha
  end
  
  it "should trace script" do
    min_server_version(2.6)
      

    Oboe::API.start_trace('redis_test', '', {}) do
      sha = @redis.script(:load, "return 1")
      @redis.script(:exists, sha)
      @redis.script(:exists, [sha, "other_sha"])
      @redis.script(:flush)
    end

    traces = get_all_traces
    traces.count.must_equal 10
    debugger
    traces[2]['KVOp'].must_equal "script"
    traces[2]['subcommand'].must_equal "load"
    traces[2]['script'].must_equal "return 1"
    traces[4]['KVOp'].must_equal "script"
    traces[4]['subcommand'].must_equal "exists"
    traces[6]['KVOp'].must_equal "script"
    traces[6]['subcommand'].must_equal "exists"
    traces[8]['KVOp'].must_equal "script"
    traces[8]['subcommand'].must_equal "flush"
  end
end

