require 'minitest_helper'
require "redis"
    
describe Oboe::Inst::Redis, :sets do
  attr_reader :entry_kvs, :exit_kvs, :redis

  def min_server_version(version)
    unless Gem::Version.new(@redis.info["redis_version"]) >= Gem::Version.new(version.to_s)
      skip "supported only on redis-server #{version} or greater" 
    end
  end

  before do
    clear_all_traces 
    
    @redis ||= Redis.new

    @redis.info["redis_version"]

    # These are standard entry/exit KVs that are passed up with all moped operations
    @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
    @exit_kvs  ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
  end

  it "should trace sadd" do
    min_server_version(1.0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sadd("shrimp", "fried")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sadd"
    traces[1]['KVKey'].must_equal "shrimp"
  end
  
  it "should trace scard" do
    min_server_version(1.0)
      
    @redis.sadd("mother sauces", "bechamel")
    @redis.sadd("mother sauces", "veloute")
    @redis.sadd("mother sauces", "espagnole")
    @redis.sadd("mother sauces", "hollandaise")
    @redis.sadd("mother sauces", "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.scard("mother sauces")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "scard"
    traces[1]['KVKey'].must_equal "mother sauces"
  end
  
  it "should trace sdiff" do
    min_server_version(1.0)

    @redis.sadd("abc", "a")
    @redis.sadd("abc", "b")
    @redis.sadd("abc", "c")
    @redis.sadd("ab", "a")
    @redis.sadd("ab", "b")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sdiff("abc", "ab")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sdiff"
    traces[1].has_key?('KVKey').must_equal false
  end
  
  it "should trace sdiffstore" do
    min_server_version(1.0)

    @redis.sadd("abc", "a")
    @redis.sadd("abc", "b")
    @redis.sadd("abc", "c")
    @redis.sadd("ab", "a")
    @redis.sadd("ab", "b")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sdiffstore("dest", "abc", "ab")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sdiffstore"
    traces[1]['destination'].must_equal "dest"
  end
  
  it "should trace sinter" do
    min_server_version(1.0)

    @redis.sadd("abc", "a")
    @redis.sadd("abc", "b")
    @redis.sadd("abc", "c")
    @redis.sadd("ab", "a")
    @redis.sadd("ab", "b")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sinter("abc", "ab")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sinter"
    traces[1].has_key?('KVKey').must_equal false
  end
  
  it "should trace sinterstore" do
    min_server_version(1.0)

    @redis.sadd("abc", "a")
    @redis.sadd("abc", "b")
    @redis.sadd("abc", "c")
    @redis.sadd("ab", "a")
    @redis.sadd("ab", "b")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sinterstore("dest", "abc", "ab")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sinterstore"
    traces[1]['destination'].must_equal "dest"
  end
  
  it "should trace sismember" do
    min_server_version(1.0)

    @redis.sadd("fibonacci", "0")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "2")
    @redis.sadd("fibonacci", "3")
    @redis.sadd("fibonacci", "5")
    @redis.sadd("fibonacci", "8")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sismember("fibonacci", "5")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sismember"
    traces[1]['KVKey'].must_equal "fibonacci"
  end
  
  it "should trace smembers" do
    min_server_version(1.0)

    @redis.sadd("fibonacci", "0")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "2")
    @redis.sadd("fibonacci", "3")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.smembers("fibonacci")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "smembers"
    traces[1]['KVKey'].must_equal "fibonacci"
  end
  
  it "should trace smove" do
    min_server_version(1.0)

    @redis.sadd("numbers", "1")
    @redis.sadd("numbers", "2")
    @redis.sadd("alpha", "two")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.smove("alpha", "numbers", "two")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "smove"
    traces[1]['source'].must_equal "alpha"
    traces[1]['destination'].must_equal "numbers"
  end
  
  it "should trace spop" do
    min_server_version(1.0)

    @redis.sadd("fibonacci", "0")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "1")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.spop("fibonacci")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "spop"
    traces[1]['KVKey'].must_equal "fibonacci"
  end
  
  it "should trace srandmember" do
    min_server_version(1.0)

    @redis.sadd("fibonacci", "0")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "1")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.srandmember("fibonacci")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "srandmember"
    traces[1]['KVKey'].must_equal "fibonacci"
  end
  
  it "should trace srem" do
    min_server_version(1.0)

    @redis.sadd("fibonacci", "0")
    @redis.sadd("fibonacci", "1")
    @redis.sadd("fibonacci", "1")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.srem("fibonacci", "0")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "srem"
    traces[1]['KVKey'].must_equal "fibonacci"
  end
  
  it "should trace sunion" do
    min_server_version(1.0)

    @redis.sadd("howard", "moe")
    @redis.sadd("howard", "curly")
    @redis.sadd("fine", "larry")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sunion("howard", "fine")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sunion"
    traces[1].has_key?('KVKey').must_equal false
  end
  
  it "should trace sunionstore" do
    min_server_version(1.0)

    @redis.sadd("howard", "moe")
    @redis.sadd("howard", "curly")
    @redis.sadd("fine", "larry")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sunionstore("dest", "howard", "fine")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sunionstore"
    traces[1]['destination'].must_equal "dest"
    traces[1].has_key?('KVKey').must_equal false
  end
  
  it "should trace sscan" do
    min_server_version(2.8)

    @redis.sadd("howard", "moe")
    @redis.sadd("howard", "curly")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.sscan("howard", 1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "sscan"
    traces[1]['KVKey'].must_equal "howard"
  end
end

