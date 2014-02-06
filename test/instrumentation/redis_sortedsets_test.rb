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

  it "should trace zadd" do
    min_server_version(1.2)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zadd("time", 0, "past")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zadd"
    traces[2]['KVKey'].must_equal "time"
  end
  
  it "should trace zcard" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zcard("sauce")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zcard"
    traces[2]['KVKey'].must_equal "sauce"
  end
  
  it "should trace zcount" do
    min_server_version(2.0)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zcount("sauce", 1, 3)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zcount"
    traces[2]['KVKey'].must_equal "sauce"
  end
  
  it "should trace zincrby" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zincrby("sauce", 1, "veloute")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zincrby"
    traces[2]['KVKey'].must_equal "sauce"
  end
  
  it "should trace zinterstore" do
    min_server_version(2.0)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    
    @redis.zadd("beverage", 0, "milkshake")
    @redis.zadd("beverage", 1, "soda")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zinterstore("zinterstore_dest", [ "sauce", "beverage" ], :weights => [2, 3])
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zinterstore"
    traces[2]['destination'].must_equal "zinterstore_dest"
    traces[2].has_key?('KVKey').must_equal false
  end
  
  it "should trace zrange" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrange("sauce", 1, 3)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrange"
    traces[2]['KVKey'].must_equal "sauce"
  end

  it "should trace zrangebyscore" do
    min_server_version(1.0)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrangebyscore("sauce", "5", "(100")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrangebyscore"
    traces[2]['KVKey'].must_equal "sauce"
  end
  
  it "should trace zrank" do
    min_server_version(2.0)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrank("sauce", "veloute")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrank"
    traces[2]['KVKey'].must_equal "sauce"
  end
  
  it "should trace zrem" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrem("sauce", "veloute")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrem"
    traces[2]['KVKey'].must_equal "sauce"
  end

  it "should trace zremrangebyrank" do
    min_server_version(2.0)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zremrangebyrank("sauce", -5, -1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zremrangebyrank"
    traces[2]['KVKey'].must_equal "sauce"
    traces[2]['start'].must_equal "-5"
    traces[2]['stop'].must_equal "-1"
  end

  it "should trace zremrangebyscore" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zremrangebyscore("sauce", -5, -1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zremrangebyscore"
    traces[2]['KVKey'].must_equal "sauce"
  end

  it "should trace zrevrange" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrevrange("sauce", 0, -1)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrevrange"
    traces[2]['KVKey'].must_equal "sauce"
    traces[2]['start'].must_equal "0"
    traces[2]['stop'].must_equal "-1"
  end

  it "should trace zrevrangebyscore" do
    min_server_version(1.2)
      
    @redis.zadd("sauce", 0, "bechamel")
    @redis.zadd("sauce", 1, "veloute")
    @redis.zadd("sauce", 2, "espagnole")
    @redis.zadd("sauce", 3, "hollandaise")
    @redis.zadd("sauce", 4, "classic tomate")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrevrangebyscore("sauce", "(100", "5")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrevrangebyscore"
    traces[2]['KVKey'].must_equal "sauce"
  end

  it "should trace zrevrank" do
    min_server_version(2.0)

    @redis.zadd("letters", 0, "a")
    @redis.zadd("letters", 1, "b")
    @redis.zadd("letters", 1, "c")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zrevrank("letters", "c")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zrevrank"
    traces[2]['KVKey'].must_equal "letters"
  end
  
  it "should trace zscore" do
    min_server_version(1.2)

    @redis.zadd("elements", 0, "fire")
    @redis.zadd("elements", 1, "water")
    @redis.zadd("elements", 1, "earth")
    @redis.zadd("elements", 1, "air")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zscore("elements", "earth")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zscore"
    traces[2]['KVKey'].must_equal "elements"
  end

  it "should trace zunionstore" do
    min_server_version(1.0)

    @redis.zadd("colors", 0, "blueish")
    @redis.zadd("colors", 1, "yellowish")
    @redis.zadd("codes", 0, "0xff")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.zunionstore("zdest", ["colors", "codes"])
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[2]['KVOp'].must_equal "zunionstore"
    traces[2]['destination'].must_equal "zdest"
    traces[2].has_key?('KVKey').must_equal false
  end
end

