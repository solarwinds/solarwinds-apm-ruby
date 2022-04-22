# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

ENV['MONGO_SERVER'] ||= "127.0.0.1:27017"
ENV['MONGO_SERVER'] += ':27017' unless ENV['MONGO_SERVER'] =~ /\:27017$/

if defined?(::Mongo::VERSION) && Mongo::VERSION >= '2.0.0'
  describe "MongoCollection" do
    before do
      @client = Mongo::Client.new([ENV['MONGO_SERVER']], :database => "solarwinds_apm-#{ENV['RACK_ENV']}")
      @db = @client.database

      if Mongo::VERSION < '2.2'
        Mongo::Logger.logger.level = Logger::INFO
      else
        @client.logger.level = Logger::INFO
      end

      @collections = @db.collection_names
      @testCollection = @client[:test_collection]
      @testCollection.create unless @collections.include? "test_collection"

      # These are standard entry/exit KVs that are passed up with all mongo operations
      @entry_kvs = {
        'Layer' => 'mongo',
        'Label' => 'entry',
        'Flavor' => 'mongodb',
        'Database' => 'solarwinds_apm-test',
        'RemoteHost' => ENV['MONGO_SERVER'] }

      @exit_kvs = { 'Layer' => 'mongo', 'Label' => 'exit' }
      @collect_backtraces = SolarWindsAPM::Config[:mongo][:collect_backtraces]
      clear_all_traces
    end

    after do
      SolarWindsAPM::Config[:mongo][:collect_backtraces] = @collect_backtraces

      if @db.collection_names.include?("temp_collection")
        @db[:temp_collection].drop
      end
    end

    it "should trace collection creation" do
      r = nil
      collection = @db[:temp_collection]
      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = collection.create
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      _(r).must_be_instance_of ::Mongo::Operation::Result
      if Mongo::VERSION < '2.2'
        _(r.successful?).must_equal true
      else
        _(r.ok?).must_equal true
      end

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[1]['QueryOp']).must_equal "create"
      _(traces[1]['New_Collection_Name']).must_equal "temp_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
    end

    it "should trace drop_collection" do
      r = nil
      collection = @db[:deleteme_collection]

      # Create something to drop unless it already exists
      unless @db.collection_names.include?("deleteme_collection")
        collection.create
      end

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = collection.drop
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      _(r).must_be_instance_of ::Mongo::Operation::Result
      if Mongo::VERSION < '2.2'
        _(r.successful?).must_equal true
      else
        _(r.ok?).must_equal true
      end

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[1]['QueryOp']).must_equal "drop"
      _(traces[1]['Collection']).must_equal "deleteme_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
    end

    it "should capture collection creation errors" do
      collection = @db[:temp_collection]
      collection.create

      begin
        SolarWindsAPM::SDK.start_trace('mongo_test') do
          collection.create
        end
      rescue
      end

      traces = get_all_traces
      _(traces.count).must_equal 5, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[3], @exit_kvs)

      _(traces[1]['QueryOp']).must_equal "create"
      _(traces[1]['New_Collection_Name']).must_equal "temp_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]

      _(traces[2]['Layer']).must_equal "mongo"
      _(traces[2]['Spec']).must_equal "error"
      _(traces[2]['Label']).must_equal "error"
      _(traces[2]['ErrorClass']).must_equal "Mongo::Error::OperationFailure"
      _(traces[2]['ErrorMsg']).must_match /[Cc]ollection.*already exists/
      _(traces[2].has_key?('Backtrace')).must_equal true
      _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1
    end

    it "should trace insert_one" do
      r = nil
      collection = @db[:tv_collection]

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = collection.insert_one({ name => 'Rabel Lasen' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      _(r).must_be_instance_of Mongo::Operation::Insert::Result
      if Mongo::VERSION < '2.2'
        _(r.successful?).must_equal true
      else
        _(r.ok?).must_equal true
      end

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[1]['QueryOp']).must_equal "insert_one"
      _(traces[1]['Collection']).must_equal "tv_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
    end

    it "should trace insert_many" do
      r = nil
      collection = @db[:tv_collection]

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = collection.insert_many([
                                     { :name => 'Rabel Lasen' },
                                     { :name => 'Louval Raiden' }])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      if Mongo::VERSION < '2.1'
        _(r).must_be_instance_of Mongo::Operation::Insert::Result
      else
        _(r).must_be_instance_of Mongo::BulkWrite::Result
        _(r.inserted_count).must_equal 2
      end

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[1]['QueryOp']).must_equal "insert_many"
      _(traces[1]['Collection']).must_equal "tv_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
    end

    it "should trace find" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.find(:name => "MyName", :limit => 1)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of Mongo::Collection::View

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\",\"limit\":1}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace find_one_and_delete" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.find_one_and_delete(:name => "MyName")
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.find_one_and_update({ :name => 'MyName' }, { "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

    it "should trace find_one_and_replace" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      clear_all_traces
      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.find_one_and_replace({ :name => 'MyName' }, { "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of BSON::Document

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "find_one_and_replace"
      _(traces[1]['Query']).must_equal "{\"name\":\"MyName\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace update_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.update_one({ :name => 'MyName' }, { "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.update_many({ :name => 'MyName' }, { "$set" => { :name => 'test1' } }, :return_document => :after)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

    it "should trace delete_one" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.delete_one({ :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

    it "should trace delete_many" do
      coll = @db[:test_collection]
      r = nil

      # Insert a doc to assure we get a result
      doc = { "name" => "MyName", "type" => "MyType", "count" => 1, "info" => { "x" => 203, "y" => '102' } }
      coll.insert_one(doc)

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.delete_many({ :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.replace_one({ :name => 'test' }, { :name => 'test1' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r.class.ancestors.include?(Mongo::Operation::Result)).must_equal true

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "replace_one"
      _(traces[1]['Query']).must_equal "{\"name\":\"test\"}"
      _(traces[1].has_key?('Query')).must_equal true
    end

    it "should trace count" do
      coll = @db[:test_collection]
      r = nil

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.count({ :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.distinct('name', { :name => 'MyName' })
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

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

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.aggregate([{ "$group" => { "_id" => "$city", "tpop" => { "$sum" => "$pop" } } }])
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      _(r).must_be_instance_of Mongo::Collection::View::Aggregation

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "aggregate"
      _(traces[1].key?('Query')).must_equal false
    end

    it "should trace bulk_write" do
      coll = @db[:test_collection]
      r = nil

      SolarWindsAPM::SDK.start_trace('mongo_test') do
        r = coll.bulk_write([{ :insert_one => { :x => 1 } },
                             { :insert_one => { :x => 3 } }],
                            :ordered => true)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4, filter_traces(traces).pretty_inspect

      validate_outer_layers(traces, 'mongo_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      if Mongo::VERSION < '2.1'
        _(r).must_be_instance_of Hash
        _(r[:n_inserted]).must_equal 2
      else
        _(r).must_be_instance_of Mongo::BulkWrite::Result
      end

      _(traces[1]['Collection']).must_equal "test_collection"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:mongo][:collect_backtraces]
      _(traces[1]['QueryOp']).must_equal "bulk_write"
      _(traces[1].key?('Query')).must_equal false
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
