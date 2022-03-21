# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

ENV['APPOPTICS_MONGO_SERVER'] ||= "127.0.0.1:27017"
ENV['APPOPTICS_MONGO_SERVER'] += ':27017' unless ENV['APPOPTICS_MONGO_SERVER'] =~ /\:27017$/

if defined?(::Mongo::VERSION) && Mongo::VERSION >= '2.0.0'
  describe "MongoCollectionView" do
    before do
      clear_all_traces

      @client = Mongo::Client.new([ENV['APPOPTICS_MONGO_SERVER']], :database => "appoptics_apm-#{ENV['RACK_ENV']}")
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
        'Database' => 'appoptics_apm-test',
        'RemoteHost' => ENV['APPOPTICS_MONGO_SERVER'] }

      @exit_kvs = { 'Layer' => 'mongo', 'Label' => 'exit' }
      @collect_backtraces = SolarWindsAPM::Config[:mongo][:collect_backtraces]
    end

    after do
      SolarWindsAPM::Config[:mongo][:collect_backtraces] = @collect_backtraces
    end

    it "should trace find_one_and_delete" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => "MyName" })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.find_one_and_delete
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of BSON::Document

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "find_one_and_delete"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace find_one_and_update" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => "MyName" })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.find_one_and_update({ "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of BSON::Document

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "find_one_and_update"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace update_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => "MyName" })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.update_one({ "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "update_one"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace update_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => "MyName" })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.update_many({ "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "update_many"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace collection delete_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => "MyName" })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.delete_one
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "delete_one"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace collection delete_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.delete_many
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "delete_many"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace collection view delete_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.delete_one
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "delete_one"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace collection view delete_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.delete_many
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "delete_many"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace replace_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)
      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.replace_one({ :name => 'test1' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "replace_one"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace count" do
      coll = @db[:test_collection]
      r = nil

      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.count({ :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.is_a?(Numeric)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "count"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace distinct" do
      coll = @db[:test_collection]
      r = nil

      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.distinct('name', { :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.is_a?(Array)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "distinct"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace aggregate" do
      coll = @db[:test_collection]
      r = nil

      cv = coll.find({ :name => 'MyName' })

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = cv.aggregate([{ "$group" => { "_id" => "$city", "tpop" => { "$sum" => "$pop" } } }])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of Mongo::Collection::View::Aggregation

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "aggregate"
      _(traces[1].key?('Query')).must_equal false
    end

    it "should trace map_reduce" do
      coll = @db[:test_collection]
      view = coll.find(:name => "MyName")

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        map = "function() { emit(this.name, 1); }"
        reduce = "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
        view.map_reduce(map, reduce, { :out => "mr_results", :limit => 100, :read => :primary })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "map_reduce"
      _(traces[1]['Map_Function']).must_equal "function() { emit(this.name, 1); }"
      _(traces[1]['Reduce_Function']).must_equal "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
      _(traces[1]['Limit']).must_equal 100
    end

    it "should obey :collect_backtraces setting when true" do
      SolarWindsAPM::Config[:mongo][:collect_backtraces] = true

      coll = @db[:test_collection]

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_has_key(traces, 'mongo', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      SolarWindsAPM::Config[:mongo][:collect_backtraces] = false

      coll = @db[:test_collection]

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
        coll.insert_one(doc)
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'mongo', 'Backtrace')
    end
  end
end
