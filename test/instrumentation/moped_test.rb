# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

# moped's newest version is from 2015, we only load it with oldgems
if defined?(::Moped)

  unless ENV['MONGO_SERVER']
    ENV['MONGO_SERVER'] = "127.0.0.1:27017"
  end

  describe "Moped" do
    before do
      clear_all_traces
      @session = Moped::Session.new([ENV['MONGO_SERVER']])
      @session.use :moped_test
      @users = @session[:users]
      @users.drop
      @users.insert({ :name => "Syd", :city => "Boston" })

      # These are standard entry/exit KVs that are passed up with all moped operations
      @entry_kvs = {
        'Layer' => 'mongo',
        'Label' => 'entry',
        'Flavor' => 'mongodb',
        'Database' => 'moped_test',
        'RemoteHost' => ENV['MONGO_SERVER'] }

      @exit_kvs = { 'Layer' => 'mongo', 'Label' => 'exit' }
      @collect_backtraces = SolarWindsAPM::Config[:moped][:collect_backtraces]
    end

    after do
      SolarWindsAPM::Config[:moped][:collect_backtraces] = @collect_backtraces
    end

    it 'Stock Moped should be loaded, defined and ready' do
      _(defined?(::Moped)).wont_match nil
      _(defined?(::Moped::Database)).wont_match nil
      _(defined?(::Moped::Indexes)).wont_match nil
      _(defined?(::Moped::Query)).wont_match nil
      _(defined?(::Moped::Collection)).wont_match nil
    end

    it 'Moped should have solarwinds_apm methods defined' do
      #::Moped::Database
      SolarWindsAPM::Inst::Moped::DB_OPS.each do |m|
        _(::Moped::Database.method_defined?("#{m}_with_sw_apm")).must_equal true
      end
      _(::Moped::Database.method_defined?(:extract_trace_details)).must_equal true
      _(::Moped::Database.method_defined?(:command_with_sw_apm)).must_equal true
      _(::Moped::Database.method_defined?(:drop_with_sw_apm)).must_equal true

      #::Moped::Indexes
      SolarWindsAPM::Inst::Moped::INDEX_OPS.each do |m|
        _(::Moped::Indexes.method_defined?("#{m}_with_sw_apm")).must_equal true
      end
      _(::Moped::Indexes.method_defined?(:extract_trace_details)).must_equal true
      _(::Moped::Indexes.method_defined?(:create_with_sw_apm)).must_equal true
      _(::Moped::Indexes.method_defined?(:drop_with_sw_apm)).must_equal true

      #::Moped::Query
      SolarWindsAPM::Inst::Moped::QUERY_OPS.each do |m|
        _(::Moped::Query.method_defined?("#{m}_with_sw_apm")).must_equal true
      end
      _(::Moped::Query.method_defined?(:extract_trace_details)).must_equal true

      #::Moped::Collection
      SolarWindsAPM::Inst::Moped::COLLECTION_OPS.each do |m|
        _(::Moped::Collection.method_defined?("#{m}_with_sw_apm")).must_equal true
      end
      _(::Moped::Collection.method_defined?(:extract_trace_details)).must_equal true
    end

    it 'should trace command' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        command = {}
        command[:mapreduce] = "users"
        command[:map] = "function() { emit(this.name, 1); }"
        command[:reduce] = "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"
        command[:out] = "inline: 1"
        @session.command(command)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "map_reduce"
      _(traces[1]['Map_Function']).must_equal "function() { emit(this.name, 1); }"
      _(traces[1]['Reduce_Function']).must_equal "function(k, vals) { var sum = 0;" +
                                                   " for(var i in vals) sum += vals[i]; return sum; }"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace drop_collection' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.drop
        @session.drop
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "drop_collection"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "drop_database"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace create_index, indexes and drop_indexes' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.indexes.create({ :name => 1 }, { :unique => true })
        @users.indexes.drop
      end

      traces = get_all_traces

      _(traces.count).must_equal 10
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "indexes"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "create_index"
      _(traces[3]['Key']).must_equal "{\"name\":1}"
      _(traces[3]['Options']).must_equal "{\"unique\":true}"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)

      validate_event_keys(traces[5], @entry_kvs)
      _(traces[5]['QueryOp']).must_equal "indexes"
      _(traces[5]['Collection']).must_equal "users"
      _(traces[5].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[6], @exit_kvs)

      validate_event_keys(traces[7], @entry_kvs)
      _(traces[7]['QueryOp']).must_equal "drop_indexes"
      _(traces[7]['Key']).must_equal "all"
      _(traces[7].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[8], @exit_kvs)
    end

    it 'should trace find and count' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find.count
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "count"
      _(traces[3]['Query']).must_equal "all"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find and sort' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").sort(:city => 1, :created_at => -1)
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "sort"
      _(traces[3]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Order']).must_equal "{:city=>1, :created_at=>-1}"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find with limit' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").limit(1)
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "limit"
      _(traces[3]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Limit']).must_equal "1"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find with distinct' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").distinct(:city)
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "distinct"
      _(traces[3]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Key']).must_equal "city"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find and update' do
      2.times { @users.insert(:name => "Mary") }
      mary_count = @users.find(:name => "Mary").count
      _(mary_count).wont_equal 0

      tool_count = @users.find(:name => "Tool").count
      _(tool_count).must_equal 0

      SolarWindsAPM::SDK.start_trace('moped_test') do
        old_attrs = { :name => "Mary" }
        new_attrs = { :name => "Tool" }
        @users.find(old_attrs).update({ '$set' => new_attrs }, { :multi => true })
      end

      new_tool_count = @users.find(:name => "Tool").count
      _(new_tool_count).must_equal mary_count

      new_mary_count = @users.find(:name => "Mary").count
      _(new_mary_count).must_equal 0

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "update"
      _(traces[3]['Update_Document']).must_equal "{\"$set\":{\"name\":\"Tool\"}}"
      _(traces[3]['Flags']).must_equal "{:multi=>true}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find and update_all' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").update_all({ :name => "Tool" })
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "update_all"
      _(traces[3]['Update_Document']).must_equal "{\"name\":\"Tool\"}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find and upsert' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Tool").upsert({ :name => "Mary" })
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Tool\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "upsert"
      _(traces[3]['Query']).must_equal "{\"name\":\"Tool\"}"
      _(traces[3]['Update_Document']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace find and explain' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").explain
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "explain"
      _(traces[3]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace 3 types of find and modify calls' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:likes => 1).modify({ "$set" => { :name => "Tool" } }, :upsert => true)
        @users.find.modify({ "$inc" => { :likes => 1 } }, :new => true)
        @users.find.modify({ :query => {} }, :remove => true)
      end

      traces = get_all_traces

      _(traces.count).must_equal 14
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"likes\":1}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "modify"
      _(traces[3]['Update_Document']).must_equal "{\"likes\":1}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3]['Options']).must_equal "{\"upsert\":true}"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)

      validate_event_keys(traces[7], @entry_kvs)
      _(traces[7]['QueryOp']).must_equal "modify"
      _(traces[7]['Update_Document']).must_equal "all"
      _(traces[7]['Collection']).must_equal "users"
      _(traces[7]['Options']).must_equal "{\"new\":true}"
      _(traces[7]['Change']).must_equal "{\"$inc\":{\"likes\":1}}"
      _(traces[7].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[8], @exit_kvs)

      validate_event_keys(traces[11], @entry_kvs)
      _(traces[11]['Collection']).must_equal "users"
      _(traces[11]['QueryOp']).must_equal "modify"
      _(traces[11]['Update_Document']).must_equal "all"
      _(traces[11]['Change']).must_equal "{\"query\":{}}"
      _(traces[11]['Options']).must_equal "{\"remove\":true}"
      _(traces[11].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[12], @exit_kvs)
    end

    it 'should trace remove' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Tool").remove
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Tool\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "remove"
      _(traces[3]['Query']).must_equal "{\"name\":\"Tool\"}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace remove_all' do
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").remove_all
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "find"
      _(traces[1]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      validate_event_keys(traces[3], @entry_kvs)
      _(traces[3]['QueryOp']).must_equal "remove_all"
      _(traces[3]['Query']).must_equal "{\"name\":\"Mary\"}"
      _(traces[3]['Collection']).must_equal "users"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace aggregate' do
      # moped is not developed since 2015, and
      # aggregate is not working with MongoDB >= 4.0
      skip
      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.aggregate(
          { '$match' => { :name => "Mary" } },
          { '$group' => { "_id" => "$name" } }
        )
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'moped_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['QueryOp']).must_equal "aggregate"
      _(traces[1]['Query']).must_equal "[{\"$match\"=>{:name=>\"Mary\"}}, {\"$group\"=>{\"_id\"=>\"$name\"}}]"
      _(traces[1]['Collection']).must_equal "users"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:moped][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it "should obey :collect_backtraces setting when true" do
      SolarWindsAPM::Config[:moped][:collect_backtraces] = true

      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").limit(1)
      end

      traces = get_all_traces
      layer_has_key(traces, 'mongo', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      SolarWindsAPM::Config[:moped][:collect_backtraces] = false

      SolarWindsAPM::SDK.start_trace('moped_test') do
        @users.find(:name => "Mary").limit(1)
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'mongo', 'Backtrace')
    end
  end
end

