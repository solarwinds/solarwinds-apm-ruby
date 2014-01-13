require 'minitest_helper'
require "redis"
    
describe Oboe::Inst::Redis, :keys do
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

  it 'Stock Redis should be loaded, defined and ready' do
    defined?(::Redis).wont_match nil 
  end
  
  it "should trace blpop" do
    skip "not implemented yet"
    min_server_version(2.0)

    @redis.lset("savage", 0, "zombie")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.blpop("savage")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "blpop"
    traces[1]['KVKey'].must_equal "savage"
    traces[1]['index'].must_equal "0"
  end
  
  it "should trace brpop" do
    skip "not implemented yet"
    min_server_version(2.0)

    @redis.lset("savage", 0, "zombie")

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.brpop("savage")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "brpop"
    traces[1]['KVKey'].must_equal "savage"
    traces[1]['index'].must_equal "0"
  end
end

