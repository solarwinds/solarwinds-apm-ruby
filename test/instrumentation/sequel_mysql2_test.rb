# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'solarwinds_apm/test'
require 'minitest_helper'

if defined?(::Sequel)

  SolarWindsAPM::Test.set_mysql2_env
  MYSQL2_DB = Sequel.connect(ENV['DATABASE_URL'])
  ENV['QUERY_LOG_FILE'] ||= '/tmp/query_log.txt'
  MYSQL2_DB.logger = Logger.new(ENV['QUERY_LOG_FILE'])

  if MYSQL2_DB.table_exists?(:items)
    MYSQL2_DB.drop_table(:items)
  end

  MYSQL2_DB.create_table :items do
    primary_key :id
    String :name
    Float :price
  end

  describe "Sequel (mysql2)" do
    before do
      # These are standard entry/exit KVs that are passed up with all sequel operations
      @entry_kvs = {
        'Layer' => 'sequel',
        'Label' => 'entry' }

      @exit_kvs = { 'Layer' => 'sequel',
                    'Label' => 'exit',
                    'Database' => 'test_db',
                    'RemoteHost' => ENV.key?('DOCKER_MYSQL_PASS') ? ENV['MYSQL_HOST'] : '127.0.0.1',
                    'RemotePort' => 3306 }

      @collect_backtraces = SolarWindsAPM::Config[:sequel][:collect_backtraces]
      @sanitize_sql = SolarWindsAPM::Config[:sanitize_sql]

     SolarWindsAPM::Config[:sequel][:collect_backtraces] = false

      clear_all_traces
    end

    after do
      SolarWindsAPM::Config[:sequel][:collect_backtraces] = @collect_backtraces
      SolarWindsAPM::Config[:sanitize_sql] = @sanitize_sql
    end

    it 'Stock sequel should be loaded, defined and ready' do
      _(defined?(::Sequel)).wont_match nil
    end

    it 'sequel should have solarwinds_apm methods defined' do
      # Sequel::Database
      _(::Sequel::Database.method_defined?(:run_with_sw_apm)).must_equal true

      # Sequel::Dataset
      _(::Sequel::Dataset.method_defined?(:execute_with_sw_apm)).must_equal true
      _(::Sequel::Dataset.method_defined?(:execute_ddl_with_sw_apm)).must_equal true
      _(::Sequel::Dataset.method_defined?(:execute_dui_with_sw_apm)).must_equal true
      _(::Sequel::Dataset.method_defined?(:execute_insert_with_sw_apm)).must_equal true
    end

    it "should obey :collect_backtraces setting when true" do
      SolarWindsAPM::Config[:sequel][:collect_backtraces] = true

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.run('select 1')
      end

      traces = get_all_traces
      layer_has_key(traces, 'sequel', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      SolarWindsAPM::Config[:sequel][:collect_backtraces] = false

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.run('select 1')
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'sequel', 'Backtrace')
    end

    it 'should trace MYSQL2_DB.run insert' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.run("insert into items (name, price) values ('blah', '12')")
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[2]['Query']).must_equal "insert into items (name, price) values ('blah', '12')"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace MYSQL2_DB.run select' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.run("select 1")
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[2]['Query']).must_equal "select 1"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace a dataset insert and count' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      items = MYSQL2_DB[:items]
      items.count

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        items.insert(:name => 'abc', :price => 2.514)
        items.count
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      # SQL column/value order can vary between Ruby and gem versions
      # Use must_include to test against one or the other
      _([
          "INSERT INTO `items` (`price`, `name`) VALUES (2.514, 'abc')",
          "INSERT INTO `items` (`name`, `price`) VALUES ('abc', 2.514)"
        ]).must_include traces[2]['Query']

      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      _(traces[2]['Layer']).must_equal "sequel"
      _(traces[2]['Label']).must_equal "exit"
      _(traces[4]['Query'].downcase).must_equal "select count(*) as `count` from `items` limit 1"
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace a dataset insert and obey query privacy' do
      SolarWindsAPM::Config[:sanitize_sql] = true
      items = MYSQL2_DB[:items]
      items.count

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        items.insert(:name => 'abc', :price => 2.514461383352462)
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      # SQL column/value order can vary between Ruby and gem versions
      # Use must_include to test against one or the other
      _([
          "INSERT INTO `items` (`price`, `name`) VALUES (?, ?)",
          "INSERT INTO `items` (`name`, `price`) VALUES (?, ?)"
        ]).must_include traces[2]['Query']

      _(traces[1].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace a dataset filter' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      items = MYSQL2_DB[:items]
      items.count

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        items.filter(:name => 'abc').all
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[2]['Query']).must_equal "SELECT * FROM `items` WHERE (`name` = 'abc')"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace create table' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      # Drop the table if it already exists
      MYSQL2_DB.drop_table(:fake) if MYSQL2_DB.table_exists?(:fake)

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.create_table :fake do
          primary_key :id
          String :name
          Float :price
        end
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[2]['Query']).must_equal "CREATE TABLE `fake` (`id` integer PRIMARY KEY AUTO_INCREMENT, `name` varchar(255), `price` double precision)"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace add index' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      # Drop the table if it already exists
      MYSQL2_DB.drop_table(:fake) if MYSQL2_DB.table_exists?(:fake)

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        MYSQL2_DB.create_table :fake do
          primary_key :id
          String :name
          Float :price
        end
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[2]['Query']).must_equal "CREATE TABLE `fake` (`id` integer PRIMARY KEY AUTO_INCREMENT, `name` varchar(255), `price` double precision)"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should capture and report exceptions' do
      begin
        SolarWindsAPM::SDK.start_trace('sequel_test') do
          MYSQL2_DB.run("this is bad sql")
        end
      rescue
        # Do nothing - we're testing exception logging
      end

      traces = get_all_traces

      _(traces.count).must_equal 5
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      _(traces[3]['Query']).must_equal "this is bad sql"
      _(traces[3].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]

      _(traces[2]['Layer']).must_equal "sequel"
      _(traces[2]['Spec']).must_equal "error"
      _(traces[2]['Label']).must_equal "error"
      _(traces[2].has_key?('Backtrace')).must_equal true
      _(traces[2].has_key?('ErrorMsg')).must_equal true
      _(traces[2]['ErrorClass']).must_equal "Sequel::DatabaseError"
      _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1

      validate_event_keys(traces[3], @exit_kvs)
    end

    it 'should trace placeholder queries with bound vars' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      items = MYSQL2_DB[:items]
      items.count

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        ds = items.where(:name => :$n)
        ds.call(:select, :n => 'abc')
        ds.call(:delete, :n => 'cba')
      end

      traces = get_all_traces

      _(traces.count).must_equal 6
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      if ::Sequel::VERSION > '4.36.0'
        _(traces[2]['Query']).must_equal "SELECT * FROM `items` WHERE (`name` = ?)"
        _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
        _(traces[4]['Query']).must_equal "DELETE FROM `items` WHERE (`name` = ?)"
        _(traces[4].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      else
        _(traces[2]['Query']).must_equal "SELECT * FROM `items` WHERE (`name` = 'abc')"
        _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
        _(traces[4]['Query']).must_equal "DELETE FROM `items` WHERE (`name` = 'cba')"
        _(traces[4].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      end
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace prepared statements' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      ds = MYSQL2_DB[:items].filter(:name => :$n)
      ps = ds.prepare(:select, :select_by_name)

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        ps.call(:n => 'abc')
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      if ::Sequel::VERSION > '4.36.0'
        _(traces[2]['Query']).must_equal "SELECT * FROM `items` WHERE (`name` = ?)"
      else
        _(traces[2]['Query']).must_equal "select_by_name"
      end

      _(traces[2]['QueryArgs']).must_equal "[\"abc\"]"
      _(traces[2]['IsPreparedStatement']).must_equal "true"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace prep\'d stmnts and obey query privacy' do
      SolarWindsAPM::Config[:sanitize_sql] = true
      ds = MYSQL2_DB[:items].filter(:name => :$n)
      ps = ds.prepare(:select, :select_by_name)

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        ps.call(:n => 'abc')
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      # TODO retire check for 4.36.0 at some point
      #      sequel 4.36.0 July 2016, sequel 4.37.0 August 2016
      if ::Sequel::VERSION > '4.36.0'
        _(traces[2]['Query']).must_equal "SELECT * FROM `items` WHERE (`name` = ?)"
      else
        _(traces[2]['Query']).must_equal "select_by_name"
      end

      _(traces[2]['QueryArgs']).must_be_nil
      _(traces[2]['IsPreparedStatement']).must_equal "true"
      _(traces[2].has_key?('Backtrace')).must_equal SolarWindsAPM::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end
  end


  ## trace id in query #########################################################

  def log_traceid_regex(trace_id)
    /\/\*traceparent='00-#{trace_id}-[0-9a-z]{16}-[01]{2}'\*\//
  end

  describe "Sequel mysql2 trace context in query" do
    before do
      if MYSQL2_DB.table_exists?(:items)
        MYSQL2_DB.drop_table(:items)
      end
      MYSQL2_DB.create_table :items do
        primary_key :id
        String :name
        Float :price
      end

      @tag_sql = SolarWindsAPM::Config[:tag_sql]
      @collect_backtraces = SolarWindsAPM::Config[:sequel][:collect_backtraces]
      @sanitize_sql = SolarWindsAPM::Config[:sanitize_sql]

      SolarWindsAPM::Config[:tag_sql] = true
      SolarWindsAPM::Config[:sequel][:collect_backtraces] = false
      SolarWindsAPM::Config[:sanitize_sql] = true
      clear_all_traces
      clear_query_log
  end

    after do
      SolarWindsAPM::Config[:sequel][:collect_backtraces] = @collect_backtraces
      SolarWindsAPM::Config[:sanitize_sql] = @sanitize_sql
      SolarWindsAPM::Config[:tag_sql] = @tag_sql
    end

    it 'adds trace context to sql string via Dataset' do
      items = MYSQL2_DB[:items]
      trace_id = ''

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        trace_id = SolarWindsAPM::TraceString.trace_id(SolarWindsAPM::Context.toString)
        items.count
      end
      traces = get_all_traces
      assert_match log_traceid_regex(trace_id), traces[2]['QueryTag']
      refute_match /traceparent/, traces[2]['Query']
      assert query_logged?(/#{log_traceid_regex(trace_id)}SELECT/), "Logged query didn't match what we're looking for"
    end

    it 'adds trace context to sql string via DB' do
      trace_id = ''

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        trace_id = SolarWindsAPM::TraceString.trace_id(SolarWindsAPM::Context.toString)
        MYSQL2_DB << 'SELECT count(*) AS "count" FROM items'
      end
      traces = get_all_traces
      assert_match log_traceid_regex(trace_id), traces[2]['QueryTag']
      refute_match /traceparent/, traces[2]['Query']
      assert query_logged?(/#{log_traceid_regex(trace_id)}SELECT/), "Logged query didn't match what we're looking for"
    end

    it 'adds trace context to query represented by a symbol via DB' do
      SolarWindsAPM::Config[:sanitize_sql] = false
      ds = MYSQL2_DB[:items].filter(:name => :$n)
      ds.prepare(:select, :select_by_name)
      trace_id = 'trace a dataset insert and count'

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        trace_id = SolarWindsAPM::TraceString.trace_id(SolarWindsAPM::Context.toString)
        MYSQL2_DB.execute(:select_by_name, { arguments: ['abc'] })
      end

      traces = get_all_traces
      assert_match log_traceid_regex(trace_id), traces[2]['QueryTag']
      refute_match /traceparent/, traces[2]['Query']
      assert query_logged?(/#{log_traceid_regex(trace_id)}SELECT/), "Logged query didn't match what we're looking for"
    end

    it 'adds trace context to ArgumentMapper aka Dataset' do
      ds = MYSQL2_DB[:items].filter(:name => :$n)
      ps = ds.prepare(:select, :select_by_name)
      trace_id = ''

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        trace_id = SolarWindsAPM::TraceString.trace_id(SolarWindsAPM::Context.toString)
        ps.call(:n => 'abc')
      end
      traces = get_all_traces
      assert_match log_traceid_regex(trace_id), traces[2]['QueryTag']
      refute_match /traceparent/, traces[2]['Query']
      assert query_logged?(/#{log_traceid_regex(trace_id)}SELECT/), "Logged query didn't match what we're looking for"
    end

    it "adds trace context to a stored procedure" do
      trace_id = ''
      MYSQL2_DB.execute('DROP PROCEDURE IF EXISTS test_sproc') # sometimes things go wrong
      MYSQL2_DB.execute_ddl('CREATE PROCEDURE test_sproc() BEGIN DELETE FROM items; END')

      SolarWindsAPM::SDK.start_trace('sequel_test') do
        trace_id = SolarWindsAPM::TraceString.trace_id(SolarWindsAPM::Context.toString)
        MYSQL2_DB.call_sproc(:test_sproc)
      end
      traces = get_all_traces
      assert_match log_traceid_regex(trace_id), traces[2]['QueryTag']
      refute_match /traceparent/, traces[2]['Query']
      assert query_logged?(/#{log_traceid_regex(trace_id)}CALL/), "Logged query didn't match what we're looking for"

      MYSQL2_DB.execute('DROP PROCEDURE IF EXISTS test_sproc')
    end
  end
end
