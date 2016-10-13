# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

unless ENV['TV_MONGO_SERVER']
  ENV['TV_MONGO_SERVER'] = "127.0.0.1:27017"
end

if defined?(::Mongo::VERSION) && Mongo::VERSION >= '2.0.0'
  describe "MongoIndex" do
    before do
      clear_all_traces

      @client = Mongo::Client.new([ ENV['TV_MONGO_SERVER'] ], :database => "traceview-#{ENV['RACK_ENV']}")
      if Mongo::VERSION < '2.2'
        Mongo::Logger.logger.level = Logger::INFO
      else
        @client.logger.level = Logger::INFO
      end
      @db = @client.database

      @collections = @db.collection_names
      @testCollection = @client[:test_collection]
      @testCollection.create unless @collections.include? "test_collection"

      # These are standard entry/exit KVs that are passed up with all mongo operations
      @entry_kvs = {
        'Layer' => 'mongo',
        'Label' => 'entry',
        'Flavor' => 'mongodb',
        'Database' => 'traceview-test',
        'RemoteHost' => ENV['TV_MONGO_SERVER'] }

      @exit_kvs = { 'Layer' => 'mongo', 'Label' => 'exit' }
      @collect_backtraces = TraceView::Config[:mongo][:collect_backtraces]
    end

    after do
      TraceView::Config[:mongo][:collect_backtraces] = @collect_backtraces
    end

    it "should trace create_one" do
      coll = @db[:test_collection]
      coll.indexes.drop_all

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.indexes.create_one({ :name => 1 })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "create_one"
    end

    it "should trace create_many" do
      coll = @db[:test_collection]
      coll.indexes.drop_all

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.indexes.create_many([ { :key => {:asdf => 1}, :unique => false },
                                   { :key => {:age => -1}, :background => true} ])
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "create_many"
    end

    it "should trace drop_one" do
      coll = @db[:test_collection]
      coll.indexes.create_one({ :name => 1 })

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.indexes.drop_one('name_1')
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "drop_one"
    end

    it "should trace drop_all" do
      coll = @db[:test_collection]
      coll.indexes.create_one({ :name => 1 })

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.indexes.drop_all
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "drop_all"
    end
  end
end
