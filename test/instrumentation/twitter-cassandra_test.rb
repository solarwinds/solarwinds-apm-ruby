# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

unless ENV['APPOPTICS_CASSANDRA_SERVER']
  ENV['APPOPTICS_CASSANDRA_SERVER'] = "127.0.0.1:9160"
end

# The cassandra-rb client doesn't support JRuby
# https://github.com/cassandra-rb/cassandra

# exclude cassandra tests for now
# TODO: they need refactoring to use the 'cassandra-driver' gem instead of the 'cassandra' gem,
# ____  which hasn't had a commit since 09/2014

if defined?(::Cassandra) and !defined?(JRUBY_VERSION)
  describe "Cassandra" do
    before do
      clear_all_traces

      @client = Cassandra.new("system", ENV['APPOPTICS_CASSANDRA_SERVER'], { :timeout => 10 })
      @client.disable_node_auto_discovery!

      @ks_name = "AppNetaCassandraTest"

      ks_def = CassandraThrift::KsDef.new(:name => @ks_name,
                                          :strategy_class => "SimpleStrategy",
                                          :strategy_options => { 'replication_factor' => '2' },
                                          :cf_defs => [])

      @client.add_keyspace(ks_def) unless @client.keyspaces.include? @ks_name
      @client.keyspace = @ks_name

      unless @client.column_families.include? "Users"
        cf_def = CassandraThrift::CfDef.new(:keyspace => @ks_name, :name => "Users")
        @client.add_column_family(cf_def)
      end

      unless @client.column_families.include? "Statuses"
        cf_def = CassandraThrift::CfDef.new(:keyspace => @ks_name, :name => "Statuses")
        @client.add_column_family(cf_def)
      end

      # These are standard entry/exit KVs that are passed up with all mongo operations
      @entry_kvs = {
        'Layer' => 'cassandra',
        'Label' => 'entry',
        'RemoteHost' => ENV['APPOPTICS_CASSANDRA_SERVER'].split(':')[0],
        'RemotePort' => ENV['APPOPTICS_CASSANDRA_SERVER'].split(':')[1] }

      @exit_kvs = { 'Layer' => 'cassandra', 'Label' => 'exit' }
      @collect_backtraces = SolarWindsAPM::Config[:cassandra][:collect_backtraces]
    end

    after do
      SolarWindsAPM::Config[:cassandra][:collect_backtraces] = @collect_backtraces
      @client.disconnect!
    end

    it 'Stock Cassandra should be loaded, defined and ready' do
      _(defined?(::Cassandra)).wont_match nil
    end

    it 'Cassandra should have appoptics_apm methods defined' do
      [:insert, :remove, :count_columns, :get_columns, :multi_get_columns, :get,
       :multi_get, :get_range_single, :get_range_batch, :get_indexed_slices,
       :create_index, :drop_index, :add_column_family, :drop_column_family,
       :add_keyspace, :drop_keyspace].each do |m|
        _(::Cassandra.method_defined?("#{m}_with_appoptics")).must_equal true
      end
      # Special 'exists?' case
      _(::Cassandra.method_defined?("exists_with_appoptics?")).must_equal true
    end

    it 'shouldn\'t break when NOT tracing' do
      begin
        user = { 'screen_name' => 'larry', "blah" => "ok" }
        @client.insert(:Users, '5', user, { :ttl => 600, :consistency => 1 })
        @client.remove(:Users, '5', 'blah')
        @client.count_columns(:Statuses, '12', :count => 50)
        @client.get_columns(:Statuses, '12', ['body'])
        @client.multi_get_columns(:Users, ['12', '5'], ['body'])
        @client.get(:Statuses, '12', :reversed => true)
        @client.get_range_keys(:Statuses, :key_count => 4)
        @client.create_index(@ks_name, 'Statuses', 'x', 'LongType')
        expressions = [
          { :column_name => 'x',
            :value => [0, 20].pack("NN"),
            :comparison => "==" },
          { :column_name => 'non_indexed',
            :value => [5].pack("N*"),
            :comparison => ">" }]
        @client.get_indexed_slices(:Statuses, expressions).length
        @client.exists?(:Statuses, '12')
        @client.exists?(:Statuses, '12', 'body')
        @client.drop_index(@ks_name, 'Statuses', 'column_name')
        @client.drop_keyspace(@ks_name)
      rescue => e
        # My crappy way to detect and fail if an exception
        # was raised.  I swear there was a Minitest assertion for
        # this but can't find it.
        _(e).must_be_nil 'broken when NOT tracing'
        raise
      end
    end

    it 'should trace insert' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        user = { 'screen_name' => 'larry', "blah" => "ok" }
        @client.insert(:Users, '5', user, { :ttl => 600, :consistency => 1 })
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "insert"
      _(traces[1]['Cf']).must_equal "Users"
      _(traces[1]['Key']).must_equal "\"5\""
      _(traces[1]['Consistency']).must_equal 1
      _(traces[1]['Ttl']).must_equal 600
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace remove' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.remove(:Users, '5', 'blah')
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "remove"
      _(traces[1]['Cf']).must_equal "Users"
      _(traces[1]['Key']).must_equal "\"5\""
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace count_columns' do
      @client.insert(:Statuses, '12', { 'body' => 'v1', 'user' => 'v2' })

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.count_columns(:Statuses, '12', :count => 50)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "count_columns"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Key']).must_equal "\"12\""
      _(traces[1]['Count']).must_equal 50
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace get_columns' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.get_columns(:Statuses, '12', ['body'])
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "get_columns"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Key']).must_equal "\"12\""
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace multi_get_columns' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.multi_get_columns(:Users, ['12', '5'], ['body'])
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "multi_get_columns"
      _(traces[1]['Cf']).must_equal "Users"
      _(traces[1]['Key']).must_equal "[\"12\", \"5\"]"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace get' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.get(:Statuses, '12', :reversed => true)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "get"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Key']).must_equal "\"12\""
      _(traces[1]['Reversed']).must_equal "true"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace exists?' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.exists?(:Statuses, '12')
        @client.exists?(:Statuses, '12', 'body')
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "exists?"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Key']).must_equal "\"12\""
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[3]['Op']).must_equal "exists?"
      _(traces[3]['Cf']).must_equal "Statuses"
      _(traces[3]['Key']).must_equal "\"12\""
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
    end

    it 'should trace get_range_keys' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.get_range_keys(:Statuses, :key_count => 4)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "get_range_batch"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace create_index' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.create_index(@ks_name, 'Statuses', 'column_name', 'LongType')
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "create_index"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Keyspace']).must_equal @ks_name
      _(traces[1]['Column_name']).must_equal "column_name"
      _(traces[1]['Validation_class']).must_equal "LongType"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      # Clean up
      @client.drop_index(@ks_name, 'Statuses', 'column_name')
    end

    it 'should trace drop_index' do
      # Prep
      @client.create_index(@ks_name, 'Statuses', 'column_name', 'LongType')

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.drop_index(@ks_name, 'Statuses', 'column_name')
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "drop_index"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1]['Keyspace']).must_equal @ks_name
      _(traces[1]['Column_name']).must_equal "column_name"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace get_indexed_slices' do
      @client.create_index(@ks_name, 'Statuses', 'x', 'LongType')
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        expressions = [
          { :column_name => 'x',
            :value => [0, 20].pack("NN"),
            :comparison => "==" },
          { :column_name => 'non_indexed',
            :value => [5].pack("N*"),
            :comparison => ">" }]
        @client.get_indexed_slices(:Statuses, expressions).length
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "get_indexed_slices"
      _(traces[1]['Cf']).must_equal "Statuses"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace add and remove of column family' do
      cf_name = (0...10).map { ('a'..'z').to_a[rand(26)] }.join
      cf_def = CassandraThrift::CfDef.new(:keyspace => @ks_name, :name => cf_name)

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.add_column_family(cf_def)
        @client.drop_column_family(cf_name)
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "add_column_family"
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)

      _(traces[3]['Op']).must_equal "drop_column_family"
      _(traces[3]['Cf']).must_equal cf_name
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
    end

    it 'should trace adding a keyspace' do
      ks_name = (0...10).map { ('a'..'z').to_a[rand(26)] }.join
      ks_def = CassandraThrift::KsDef.new(:name => ks_name,
                                          :strategy_class => "org.apache.cassandra.locator.SimpleStrategy",
                                          :strategy_options => { 'replication_factor' => '2' },
                                          :cf_defs => [])

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.add_keyspace(ks_def)
        @client.keyspace = ks_name
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "add_keyspace"
      _(traces[1]['Name']).must_equal ks_name
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace the removal of a keyspace' do
      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        @client.drop_keyspace(@ks_name)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'cassandra_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[1]['Op']).must_equal "drop_keyspace"
      _(traces[1]['Name']).must_equal @ks_name
      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:cassandra][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it "should obey :collect_backtraces setting when true" do
      SolarWindsAPM::Config[:cassandra][:collect_backtraces] = true

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        user = { 'screen_name' => 'larry', "blah" => "ok" }
        @client.insert(:Users, '5', user, { :ttl => 600, :consistency => 1 })
      end

      traces = get_all_traces
      layer_has_key(traces, 'cassandra', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      SolarWindsAPM::Config[:cassandra][:collect_backtraces] = false

      SolarWindsAPM::SDK.start_trace('cassandra_test') do
        user = { 'screen_name' => 'larry', "blah" => "ok" }
        @client.insert(:Users, '5', user, { :ttl => 600, :consistency => 1 })
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'cassandra', 'Backtrace')
    end

  end
end
