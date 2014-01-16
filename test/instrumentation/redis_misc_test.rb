require 'minitest_helper'
require "redis"
    
describe Oboe::Inst::Redis, :misc do
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

  it "should trace publish" do
    min_server_version(2.0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.publish("channel1", "Broadcasting live from silicon circuits.")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "publish"
    traces[1]['channel'].must_equal "channel1"
    traces[1].has_key?('KVKey').must_equal false
  end
  
  it "should trace select" do
    min_server_version(2.0)

    Oboe::API.start_trace('redis_test', '', {}) do
      @redis.select(2)
    end

    traces = get_all_traces
    traces.count.must_equal 4
    traces[1]['KVOp'].must_equal "select"
    traces[1]['db'].must_equal "2"
  end
  
end

