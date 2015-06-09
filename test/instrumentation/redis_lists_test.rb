require 'minitest_helper'

if defined?(::Redis)
  describe "Redis Lists" do
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


    it "should trace blpop" do
      min_server_version(2.0)

      @redis.lpush("savage", "zombie")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.blpop("savage")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "blpop"
      traces[2]['KVKey'].must_equal "savage"
    end

    it "should trace brpop" do
      min_server_version(2.0)

      @redis.lpush("savage", "the walking dead")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.brpop("savage")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "brpop"
      traces[2]['KVKey'].must_equal "savage"
    end

    it "should trace brpoplpush" do
      min_server_version(2.2)

      @redis.lpush("savage", "night of the walking dead")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.brpoplpush("savage", "crawlies")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "brpoplpush"
      traces[2]['destination'].must_equal "crawlies"
    end

    it "should trace lindex" do
      min_server_version(1.0)

      @redis.lpush("fringe", "bishop")
      @redis.lpush("fringe", "dunham")
      @redis.lpush("fringe", "broyles")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lindex("fringe", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lindex"
      traces[2]['index'].must_equal 1
    end

    it "should trace linsert" do
      min_server_version(2.2)

      @redis.lpush("gods of old", "sun")
      @redis.lpush("gods of old", "moon")
      @redis.lpush("gods of old", "night")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.linsert("gods of old", "BEFORE", "night", "river")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "linsert"
      traces[2]['KVKey'].must_equal "gods of old"
    end

    it "should trace llen" do
      min_server_version(1.0)

      @redis.lpush("gods of old", "sun")
      @redis.lpush("gods of old", "moon")
      @redis.lpush("gods of old", "night")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.llen("gods of old")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "llen"
      traces[2]['KVKey'].must_equal "gods of old"
    end

    it "should trace lpop" do
      min_server_version(1.0)

      @redis.lpush("gods of old", "sun")
      @redis.lpush("gods of old", "moon")
      @redis.lpush("gods of old", "night")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lpop("gods of old")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lpop"
      traces[2]['KVKey'].must_equal "gods of old"
    end

    it "should trace lpush" do
      min_server_version(1.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lpush("gods of old", "night")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lpush"
      traces[2]['KVKey'].must_equal "gods of old"
    end

    it "should trace lpushx" do
      min_server_version(2.2)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lpushx("gods of old", "night")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lpushx"
      traces[2]['KVKey'].must_equal "gods of old"
    end

    it "should trace lrange" do
      min_server_version(1.0)

      @redis.rpush("protein types", "structural")
      @redis.rpush("protein types", "storage")
      @redis.rpush("protein types", "hormonal")
      @redis.rpush("protein types", "enzyme")
      @redis.rpush("protein types", "immunoglobulins")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lrange("protein types", 2, 4)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lrange"
      traces[2]['KVKey'].must_equal "protein types"
      traces[2]['start'].must_equal 2
      traces[2]['stop'].must_equal 4
    end

    it "should trace lrem" do
      min_server_version(1.0)

      @redis.rpush("australia", "sydney")
      @redis.rpush("australia", "sydney")
      @redis.rpush("australia", "albury")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "penrith")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lrem("australia", -2, "sydney")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lrem"
      traces[2]['KVKey'].must_equal "australia"
    end

    it "should trace lset" do
      min_server_version(1.0)

      @redis.rpush("australia", "sydney")
      @redis.rpush("australia", "albury")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "penrith")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.lset("australia", 2, "Kalgoorlie")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "lset"
      traces[2]['KVKey'].must_equal "australia"
    end

    it "should trace ltrim" do
      min_server_version(1.0)

      @redis.rpush("australia", "sydney")
      @redis.rpush("australia", "albury")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "albury")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "albury")
      @redis.rpush("australia", "tamworth")
      @redis.rpush("australia", "penrith")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.ltrim("australia", 2, 6)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "ltrim"
      traces[2]['KVKey'].must_equal "australia"
    end

    it "should trace rpop" do
      min_server_version(1.0)

      @redis.rpush("santa esmeralda", "house of the rising sun")
      @redis.rpush("santa esmeralda", "don't let me be misunderstood")
      @redis.rpush("santa esmeralda", "sevilla nights")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.rpop("santa esmeralda")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "rpop"
      traces[2]['KVKey'].must_equal "santa esmeralda"
    end

    it "should trace rpoplpush" do
      min_server_version(1.2)

      @redis.rpush("santa esmeralda", "house of the rising sun")
      @redis.rpush("santa esmeralda", "don't let me be misunderstood")
      @redis.rpush("santa esmeralda", "sevilla nights")

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.rpoplpush("santa esmeralda", "the gods of old")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "rpoplpush"
      traces[2]['KVKey'].must_equal "santa esmeralda"
      traces[2]['destination'].must_equal "the gods of old"
    end

    it "should trace rpush" do
      min_server_version(1.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.rpush("boney m", "rasputin")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "rpush"
      traces[2]['KVKey'].must_equal "boney m"
    end

    it "should trace rpushx" do
      min_server_version(1.0)

      TraceView::API.start_trace('redis_test', '', {}) do
        @redis.rpushx("boney m", "rasputin")
      end

      traces = get_all_traces
      traces.count.must_equal 4
      traces[2]['KVOp'].must_equal "rpushx"
      traces[2]['KVKey'].must_equal "boney m"
    end
  end
end
