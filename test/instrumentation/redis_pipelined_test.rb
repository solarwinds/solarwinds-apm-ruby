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
  
end

