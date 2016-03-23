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

    it "should log and pass on exceptions" do
      skip
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

      traces[1]['QueryOp'].must_equal "create_collection"
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
      TV.pry!
      traces.count.must_equal 4

      r.must_be_instance_of ::Mongo::Operation::Result
      r.ok?.must_equal true

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['QueryOp'].must_equal "drop_collection"
      traces[1]['Collection'].must_equal "deleteme_collection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
    end

    it "should trace count" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.count(:query => {:name => "MyName"})
      end

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[3]['QueryOp'].must_equal "count"
    end

    it "should trace find_and_modify" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.find_and_modify({ :query => { :name => "MyName" }, :update => { :count => 203 }})
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find_and_modify"
      traces[1]['Update_Document'].must_equal "{:count=>203}"
    end

    it "should trace insert" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.insert_one(doc)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "insert_one"
      # Don't test exact hash value since to_json hash ordering varies between 1.8.7 and 1.9+
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace map_reduce" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        map    = "function() { emit(this.name, 1); }"
        reduce = "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
        coll.map_reduce(map, reduce, { :out => "mr_results", :limit => 100, :read => :primary })
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

    it "should trace remove" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.remove(:name => "SaveOp")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "remove"
      traces[1]['Query'].must_equal "{\"name\":\"SaveOp\"}"
    end

    it "should trace rename" do
      skip
      coll = @db.collection("testCollection")
      new_name = (0...10).map{ ('a'..'z').to_a[rand(26)] }.join

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.rename(new_name)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "rename"
      traces[1]['New_Collection_Name'].must_equal new_name

      # Clean up after test and set collection name back to original
      coll.rename("testCollection")
    end

    it "should trace update" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        # Two types of update calls
        coll.update({"_id" => 1}, { "$set" => {"name" => "MongoDB Ruby"}}, :multi => true)

        doc = {"name" => "MyOtherName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.update({"_id" => 1}, doc)
      end

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "update"
      traces[1]['Query'].must_equal "{\"_id\":1}"

      validate_event_keys(traces[3], @entry_kvs)
      validate_event_keys(traces[4], @exit_kvs)

      traces[3].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[3]['QueryOp'].must_equal "update"
      traces[3]['Query'].must_equal "{\"_id\":1}"
    end

    it "should trace distinct" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.distinct("count")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "distinct"
    end

    it "should trace find" do
      skip
      coll = @db.collection("testCollection")
      result = nil

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      # If given an optional block +find+ will yield a Cursor to that block,
      # close the cursor, and then return nil. This guarantees that partially
      # evaluated cursors will be closed. If given no block +find+ returns a
      # cursor.
      # https://github.com/mongodb/mongo-ruby-driver/blob/1.10.1/lib/mongo/collection.rb#L178

      TraceView::API.start_trace('mongo_test', '', {}) do
        result = coll.find(:name => "MyName", :limit => 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      result.wont_match nil
      result.is_a?(Mongo::Cursor).must_equal true
      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find"
      traces[1].has_key?('Query').must_equal true
      traces[1]['Limit'].must_equal 1
    end

    it "should trace find (with block)" do
      skip
      coll = @db.collection("testCollection")
      result = []

      # Insert a doc to assure we get a result
      doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
      coll.insert_one(doc)

      # If given an optional block +find+ will yield a Cursor to that block,
      # close the cursor, and then return nil. This guarantees that partially
      # evaluated cursors will be closed. If given no block +find+ returns a
      # cursor.
      # https://github.com/mongodb/mongo-ruby-driver/blob/1.10.1/lib/mongo/collection.rb#L178

      TraceView::API.start_trace('mongo_test', '', {}) do
        blk = lambda { |x| x }
        result = coll.find(:name => "MyName", :limit => 10, &blk)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      result.must_equal nil
      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "find"
      traces[1].has_key?('Query').must_equal true
    end

    it "should trace group" do
      skip
      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        coll.group( :key =>  :type,
                    :cond => { :count => 1 },
                    :initial =>  { :count => 0 },
                    :reduce => 'function(obj,prev) { prev.count += obj.c; }')
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['Collection'].must_equal "testCollection"
      traces[1].has_key?('Backtrace').must_equal TraceView::Config[:mongo][:collect_backtraces]
      traces[1]['QueryOp'].must_equal "group"
      # Don't test exact hash value since to_json hash ordering varies between 1.8.7 and 1.9+
      traces[1].has_key?('Query').must_equal true
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
      skip
      TraceView::Config[:mongo][:collect_backtraces] = true

      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_has_key(traces, 'mongo', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      skip
      TraceView::Config[:mongo][:collect_backtraces] = false

      coll = @db.collection("testCollection")

      TraceView::API.start_trace('mongo_test', '', {}) do
        doc = {"name" => "MyName", "type" => "MyType", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'mongo', 'Backtrace')
    end
  end
end
