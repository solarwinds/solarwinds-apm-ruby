# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

if defined?(::Redis)

  describe "Redis Keys" do
    attr_reader :entry_kvs, :exit_kvs, :redis, :redis_version

    def min_server_version(version)
      unless Gem::Version.new(@redis_version) >= Gem::Version.new(version.to_s)
        skip "supported only on redis-server #{version} or greater"
      end
    end

    before do
      clear_all_traces

      @redis ||= Redis.new(:host => ENV['REDIS_HOST'] || ENV['REDIS_SERVER'] || '127.0.0.1',
                           :password => ENV['REDIS_PASSWORD'] || 'secret_pass')

      @redis_version ||= @redis.info["redis_version"]

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'entry' }
      @exit_kvs ||= { 'Layer' => 'redis_test', 'Label' => 'exit' }
      @exists_returns_integer = Redis.exists_returns_integer if defined? Redis.exists_returns_integer
    end

    after do
      Redis.exists_returns_integer = @exists_returns_integer if defined? Redis.exists_returns_integer
    end

    it 'Stock Redis should be loaded, defined and ready' do
      _(defined?(::Redis)).wont_match nil
    end

    it "should trace del" do
      @redis.setex("del_test", 60, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.del("del_test")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "del"
      _(traces[2]['KVKey']).must_equal "del_test"
    end

    it "should trace del of multiple keys" do
      @redis.setex("del_test", 60, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.del(["del_test", "noexist", "maybe"])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "del"
      _(traces[2].has_key?('KVKey')).must_equal false
    end

    it "should trace dump" do
      min_server_version(2.6)

      @redis.setex("dump_test", 60, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.dump("del_test")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "dump"
      _(traces[2]['KVKey']).must_equal "del_test"
    end

    it "should trace exists " do
      Redis.exists_returns_integer = false if defined? Redis.exists_returns_integer
      @redis.setex("talking_heads", 60, "burning down the house")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @it_exists = @redis.exists("talking_heads")
      end

      _(@it_exists).must_equal true

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "exists"
      _(traces[2]['KVKey']).must_equal "talking_heads"
    end

    it "should trace exists" do
      skip unless defined? Redis.exists_returns_integer
      Redis.exists_returns_integer = true
      @redis.setex("talking_heads", 60, "burning down the house")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @it_exists = @redis.exists("talking_heads")
      end

      _(@it_exists).must_equal 1

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "exists"
      _(traces[2]['KVKey']).must_equal "talking_heads"
    end

    it "should trace exists?" do
      skip unless defined? @redis.exists?
      @redis.setex("talking_heads", 60, "burning down the house")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @it_exists = @redis.exists?("talking_heads")
      end

      _(@it_exists).must_equal true

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "exists"
      _(traces[2]['KVKey']).must_equal "talking_heads"
    end

    it "should trace expire" do
      @redis.set("expire_please", "burning down the house")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.expire("expire_please", 120)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "expire"
      _(traces[2]['KVKey']).must_equal "expire_please"
    end

    it "should trace expireat" do
      @redis.set("expireat_please", "burning down the house")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.expireat("expireat_please", Time.now.to_i)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "expireat"
      _(traces[2]['KVKey']).must_equal "expireat_please"
    end

    it "should trace keys" do
      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.keys("del*")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "keys"
      _(traces[2]['pattern']).must_equal "del*"
    end

    it "should trace basic move" do
      @redis.set("piano", Time.now)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.move("piano", 1)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "move"
      _(traces[2]['KVKey']).must_equal "piano"
      _(traces[2]['db']).must_equal 1
    end

    it "should trace persist" do
      min_server_version(2.2)

      @redis.setex("mine", 60, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.persist("mine")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "persist"
      _(traces[2]['KVKey']).must_equal "mine"
    end

    it "should trace pexpire" do
      min_server_version(2.6)

      @redis.set("sand", "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @rv = @redis.pexpire("sand", 8000)
      end

      _(@rv).must_equal true

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "pexpire"
      _(traces[2]['KVKey']).must_equal "sand"
      _(traces[2]['milliseconds']).must_equal 8000
    end

    it "should trace pexpireat" do
      min_server_version(2.6)

      @redis.set("sand", "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @rv = @redis.pexpireat("sand", 8000)
      end

      _(@rv).must_equal true

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "pexpireat"
      _(traces[2]['KVKey']).must_equal "sand"
      _(traces[2]['milliseconds']).must_equal 8000
    end

    it "should trace pttl" do
      min_server_version(2.6)

      @redis.setex("sand", 120, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.pttl("sand")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "pttl"
      _(traces[2]['KVKey']).must_equal "sand"
    end

    it "should trace randomkey" do
      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.randomkey()
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "randomkey"
    end

    it "should trace rename" do
      @redis.setex("sand", 120, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.rename("sand", "sandy")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "rename"
      _(traces[2]['KVKey']).must_equal "sand"
      _(traces[2]['newkey']).must_equal "sandy"
    end

    it "should trace renamenx" do
      @redis.setex("sand", 120, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.renamenx("sand", "sandy")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "renamenx"
      _(traces[2]['KVKey']).must_equal "sand"
      _(traces[2]['newkey']).must_equal "sandy"
    end

    it "should trace restore" do
      min_server_version(2.6)

      @redis.setex("qubit", 60, "zero")
      x = @redis.dump("qubit")
      @redis.del "blue"

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.restore("blue", 0, x)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "restore"
      _(traces[2]['KVKey']).must_equal "blue"
      _(traces[2]['ttl']).must_equal 0
    end

    it "should trace sort" do
      min_server_version(2.2)

      @redis.rpush("penguin", "one")
      @redis.rpush("penguin", "two")
      @redis.rpush("penguin", "three")
      @redis.rpush("penguin", "four")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.sort("penguin", :order => "desc alpha", :store => "target")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "sort"
      _(traces[2]['KVKey']).must_equal "penguin"
    end

    it "should trace ttl" do
      min_server_version(2.6)

      @redis.setex("sand", 120, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.ttl("sand")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "ttl"
      _(traces[2]['KVKey']).must_equal "sand"
    end

    it "should trace type" do
      min_server_version(2.6)

      @redis.setex("sand", 120, "blah")

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.type("sand")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "type"
      _(traces[2]['KVKey']).must_equal "sand"
    end

    it "should trace scan" do
      min_server_version(2.8)

      SolarWindsAPM::SDK.start_trace('redis_test') do
        @redis.scan(0)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4
      _(traces[2]['KVOp']).must_equal "scan"
    end
  end
end
