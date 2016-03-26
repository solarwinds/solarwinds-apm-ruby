# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

unless ENV['TV_MONGO_SERVER']
  ENV['TV_MONGO_SERVER'] = "127.0.0.1:27017"
end

if defined?(::Mongo::VERSION) && Mongo::VERSION >= '2.0.0'
  describe "Mongo" do
    before do
      clear_all_traces

      @client = Mongo::Client.new([ ENV['TV_MONGO_SERVER'] ], :database => "traceview-#{ENV['RACK_ENV']}")
      @client.logger.level = Logger::INFO
      @db = @client.database

      @collections = @db.collection_names
      @testCollection = @client[:testCollection]
      @testCollection.create unless @collections.include? "testCollection"

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

      if @db.collection_names.include?("temp_collection")
        @db[:temp_collection].drop
      end
    end

    it "should trace collection creation" do
      r = nil
      collection = @db[:temp_collection]
      TraceView::API.start_trace('mongo_test', nil, {}) do
        r = collection.create
      end

      traces = get_all_traces
      traces.count.must_equal 4

      r.must_be_instance_of ::Mongo::Operation::Result
      r.ok?.must_equal true

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['QueryOp'].must_equal "create"
      traces[1]['New_Collection_Name'].must_equal "temp_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
    end

    it "should trace drop_collection" do
      r = nil
      collection = @db[:deleteme_collection]

      # Create something to drop unless it already exists
      unless @db.collection_names.include?("deleteme_collection")
        collection.create
      end

      TraceView::API.start_trace('mongo_test', nil, {}) do
        r = collection.drop
      end

      traces = get_all_traces
      traces.count.must_equal 4

      r.must_be_instance_of ::Mongo::Operation::Result
      r.ok?.must_equal true

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['QueryOp'].must_equal "drop"
      traces[1]['Collection'].must_equal "deleteme_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
    end

    it "should capture collection creation errors" do
      collection = @db[:temp_collection]
      collection.create

      begin
        TraceView::API.start_trace('mongo_test', nil, {}) do
          collection.create
        end
      rescue
      end

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[3], @exit_kvs)

      traces[1]['QueryOp'].must_equal "create"
      traces[1]['New_Collection_Name'].must_equal "temp_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]

      traces[2]['Layer'].must_equal "mongo"
      traces[2]['Label'].must_equal "error"
      traces[2]['ErrorClass'].must_equal "Mongo::Error::OperationFailure"
      traces[2]['ErrorMsg'].must_equal "collection already exists ()"
      traces[2].has_key?('Backtrace').must_equal true
    end

    it "should trace insert_one" do
      r = nil
      collection = @db[:tv_collection]

      TraceView::API.start_trace('mongo_test', nil, {}) do
        r = collection.insert_one({ name => 'Rabel Lasen' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      r.must_be_instance_of Mongo::Operation::Write::Insert::Result
      r.ok?.must_equal true

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['QueryOp'].must_equal "insert_one"
      traces[1]['Collection'].must_equal "tv_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
    end

    it "should trace insert_many" do
      r = nil
      collection = @db[:tv_collection]

      TraceView::API.start_trace('mongo_test', nil, {}) do
        r = collection.insert_many([
          { :name => 'Rabel Lasen' },
          { :name => 'Louval Raiden' }])
      end

      traces = get_all_traces
      traces.count.must_equal 4

      r.must_be_instance_of Mongo::BulkWrite::Result
      r.inserted_count.must_equal 2

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['QueryOp'].must_equal "insert_many"
      traces[1]['Collection'].must_equal "tv_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
    end

    it "should trace find" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.find(:name => "MyName", :limit => 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of Mongo::Collection::View

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\",\"limit\":1}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace find_one_and_delete" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.find_one_and_delete(:name => "MyName")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of BSON::Document

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find_one_and_delete"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace find_one_and_update" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.find_one_and_update({ :name => 'MyName' }, { "$set" => { :name => 'test1' }}, :return_document => :after)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of BSON::Document

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find_one_and_update"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace find_one_and_replace" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.find_one_and_replace({ :name => 'MyName' }, { "$set" => { :name => 'test1' }}, :return_document => :after)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of BSON::Document

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find_one_and_replace"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace update_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.update_one({ :name => 'MyName' }, { "$set" => { :name => 'test1' }}, :return_document => :after)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.class.ancestors.include?(Mongo::Operation::Result).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "update_one"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace update_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.update_many({ :name => 'MyName' }, { "$set" => { :name => 'test1' }}, :return_document => :after)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.class.ancestors.include?(Mongo::Operation::Result).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "update_many"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace delete_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.delete_one({ :name => 'MyName' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.class.ancestors.include?(Mongo::Operation::Result).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "delete_one"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace delete_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.delete_many({ :name => 'MyName' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.class.ancestors.include?(Mongo::Operation::Result).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "delete_many"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace replace_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.replace_one({ :name => 'test' }, { :name => 'test1' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.class.ancestors.include?(Mongo::Operation::Result).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "replace_one"
      traces[1]['Query'].must_equal "{\"name\":\"test\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace count" do
      coll = @db[:test_collection]
      r = nil

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.count({ :name => 'MyName' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.is_a?(Numeric).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "count"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace distinct" do
      coll = @db[:test_collection]
      r = nil

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.distinct('name', { :name => 'MyName' })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.is_a?(Array).must_equal true

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "distinct"
      traces[1]['Query'].must_equal "{\"name\":\"MyName\"}"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace aggregate" do
      coll = @db[:test_collection]
      r = nil

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.aggregate([ { "$group" => { "_id" => "$city", "tpop" => { "$sum" => "$pop" }}} ])
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of Mongo::Collection::View::Aggregation

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "aggregate"
      traces[1].key?('Query').must_equal false
    end

    it "should trace bulk_write" do
      coll = @db[:test_collection]
      r = nil

      TraceView::API.start_trace('mongo_test', '', {}) do
        r = coll.bulk_write([ { :insert_one => { :x => 1} },
                              { :update_one => { :filter => { :x => 1 }, :update => {'$set' => { :x => 2 }} } },
                              { :replace_one => { :filter => { :x => 2 }, :replacement => { :x => 3 } } } ],
                              :ordered => true)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      r.must_be_instance_of Mongo::BulkWrite::Result

      traces[1]['Collection'].must_equal "test_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "bulk_write"
      traces[1].key?('Query').must_equal false
    end

    it "should trace map_reduce" do
      skip
      coll = @db[:test_collection]
      view = coll.find(:name => "MyName")

      TraceView::API.start_trace('mongo_test', '', {}) do
        map    = "function() { emit(this.name, 1); }"
        reduce = "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
        view.map_reduce(map, reduce, { :out => "mr_results", :limit => 100, :read => :primary })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "map_reduce"
      traces[1]['Map_Function'].must_equal "function() { emit(this.name, 1); }"
      traces[1]['Reduce_Function'].must_equal "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
      traces[1]['Limit'].must_equal 100
    end

    it "should trace create, ensure and drop index" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.create_index("i")
        coll.ensure_index("i")
        coll.drop_index("i_1")
      end

      traces = get_all_traces
      traces.count.must_equal 8

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "create_index"

      validate_event_keys(traces[3], @entry_kvs)
      validate_event_keys(traces[4], @exit_kvs)

      traces[3]['Collection'].must_equal "testCollection"
      traces[3].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[3]['QueryOp'].must_equal "ensure_index"

      validate_event_keys(traces[5], @entry_kvs)
      validate_event_keys(traces[6], @exit_kvs)

      traces[5]['Collection'].must_equal "testCollection"
      traces[5].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[5]['QueryOp'].must_equal "drop_index"
    end

    it "should trace drop_indexes" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.drop_indexes
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "drop_indexes"
    end

    it "should trace index_information" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.index_information
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "index_information"
    end

    it "should obey :collect_backtraces setting when true" do
      TraceView::Config[:mongo][:collect_backtraces] = true

      coll = @db[:test_collection]

      TraceView::API.start_trace('mongo_test', '', {}) do
        doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_has_key(traces, 'mongo', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      TraceView::Config[:mongo][:collect_backtraces] = false

      coll = @db[:test_collection]

      TraceView::API.start_trace('mongo_test', '', {}) do
        doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'mongo', 'Backtrace')
    end
  end
end
