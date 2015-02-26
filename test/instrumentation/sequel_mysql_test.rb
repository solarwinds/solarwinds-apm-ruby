require 'minitest_helper'

unless defined?(JRUBY_VERSION)

  if ENV.key?('TRAVIS_MYSQL_PASS')
    MYSQL_DB = Sequel.connect("mysql://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/travis_ci_test")
  else
    MYSQL_DB = Sequel.connect('mysql://root@127.0.0.1:3306/travis_ci_test')
  end

  unless MYSQL_DB.table_exists?(:items)
    MYSQL_DB.create_table :items do
      primary_key :id
      String :name
      Float :price
    end
  end

  describe "Oboe::Inst::Sequel (mysql)" do
    before do
      clear_all_traces

      # These are standard entry/exit KVs that are passed up with all sequel operations
      @entry_kvs = {
        'Layer' => 'sequel',
        'Label' => 'entry',
        'Database' => 'travis_ci_test',
        'RemoteHost' => '127.0.0.1',
        'RemotePort' => 3306 }

      @exit_kvs = { 'Layer' => 'sequel', 'Label' => 'exit' }
      @collect_backtraces = Oboe::Config[:sequel][:collect_backtraces]
      @sanitize_sql = Oboe::Config[:sanitize_sql]
    end

    after do
      Oboe::Config[:sequel][:collect_backtraces] = @collect_backtraces
      Oboe::Config[:sanitize_sql] = @sanitize_sql
    end

    it 'Stock sequel should be loaded, defined and ready' do
      defined?(::Sequel).wont_match nil
    end

    it 'sequel should have oboe methods defined' do
      # Sequel::Database
      ::Sequel::Database.method_defined?(:run_with_oboe).must_equal true

      # Sequel::Dataset
      ::Sequel::Dataset.method_defined?(:execute_with_oboe).must_equal true
      ::Sequel::Dataset.method_defined?(:execute_ddl_with_oboe).must_equal true
      ::Sequel::Dataset.method_defined?(:execute_dui_with_oboe).must_equal true
      ::Sequel::Dataset.method_defined?(:execute_insert_with_oboe).must_equal true
    end

    it "should obey :collect_backtraces setting when true" do
      Oboe::Config[:sequel][:collect_backtraces] = true

      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.run('select 1')
      end

      traces = get_all_traces
      layer_has_key(traces, 'sequel', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      Oboe::Config[:sequel][:collect_backtraces] = false

      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.run('select 1')
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'sequel', 'Backtrace')
    end

    it 'should trace MYSQL_DB.run insert' do
      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.run("insert into items (name, price) values ('blah', '12')")
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "insert into items (name, price) values ('blah', '12')"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace MYSQL_DB.run select' do
      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.run("select 1")
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "select 1"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace a dataset insert and count' do
      items = MYSQL_DB[:items]
      items.count

      Oboe::API.start_trace('sequel_test', '', {}) do
        items.insert(:name => 'abc', :price => 2.514461383352462)
        items.count
      end

      traces = get_all_traces

      traces.count.must_equal 6
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      # SQL column/value order can vary between Ruby and gem versions
      # Use must_include to test against one or the other
      [
       "INSERT INTO `items` (`price`, `name`) VALUES (2.51446138335246, 'abc')",
       "INSERT INTO `items` (`name`, `price`) VALUES ('abc', 2.514461383352462)"
      ].must_include traces[1]['Query']

      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      traces[2]['Layer'].must_equal "sequel"
      traces[2]['Label'].must_equal "exit"
      traces[3]['Query'].downcase.must_equal "select count(*) as `count` from `items` limit 1"
      validate_event_keys(traces[4], @exit_kvs)
    end

    it 'should trace a dataset insert and obey query privacy' do
      Oboe::Config[:sanitize_sql] = true
      items = MYSQL_DB[:items]
      items.count

      Oboe::API.start_trace('sequel_test', '', {}) do
        items.insert(:name => 'abc', :price => 2.514461383352462)
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)

      # SQL column/value order can vary between Ruby and gem versions
      # Use must_include to test against one or the other
      [
       "INSERT INTO `items` (`price`, `name`) VALUES (?, ?)",
       "INSERT INTO `items` (`name`, `price`) VALUES (?, ?)"
      ].must_include traces[1]['Query']

      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace a dataset filter' do
      items = MYSQL_DB[:items]
      items.count

      Oboe::API.start_trace('sequel_test', '', {}) do
        items.filter(:name => 'abc').all
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "SELECT * FROM `items` WHERE (`name` = 'abc')"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace create table' do
      # Drop the table if it already exists
      MYSQL_DB.drop_table(:fake) if MYSQL_DB.table_exists?(:fake)

      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.create_table :fake do
          primary_key :id
          String :name
          Float :price
        end
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "CREATE TABLE `fake` (`id` integer PRIMARY KEY AUTO_INCREMENT, `name` varchar(255), `price` double precision)"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace add index' do
      # Drop the table if it already exists
      MYSQL_DB.drop_table(:fake) if MYSQL_DB.table_exists?(:fake)

      Oboe::API.start_trace('sequel_test', '', {}) do
        MYSQL_DB.create_table :fake do
          primary_key :id
          String :name
          Float :price
        end
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "CREATE TABLE `fake` (`id` integer PRIMARY KEY AUTO_INCREMENT, `name` varchar(255), `price` double precision)"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should capture and report exceptions' do
      begin
        Oboe::API.start_trace('sequel_test', '', {}) do
          MYSQL_DB.run("this is bad sql")
        end
      rescue
        # Do nothing - we're testing exception logging
      end

      traces = get_all_traces

      traces.count.must_equal 5
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "this is bad sql"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      traces[2]['Layer'].must_equal "sequel"
      traces[2]['Label'].must_equal "error"
      traces[2].has_key?('Backtrace').must_equal true
      traces[2]['ErrorClass'].must_equal "Sequel::DatabaseError"
      validate_event_keys(traces[3], @exit_kvs)
    end

    it 'should trace placeholder queries with bound vars' do
      items = MYSQL_DB[:items]
      items.count

      Oboe::API.start_trace('sequel_test', '', {}) do
        ds = items.where(:name=>:$n)
        ds.call(:select, :n=>'abc')
        ds.call(:delete, :n=>'cba')
      end

      traces = get_all_traces

      traces.count.must_equal 6
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "SELECT * FROM `items` WHERE (`name` = 'abc')"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      traces[3]['Query'].must_equal "DELETE FROM `items` WHERE (`name` = 'cba')"
      traces[3].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace prepared statements' do
      ds = MYSQL_DB[:items].filter(:name=>:$n)
      ps = ds.prepare(:select, :select_by_name)

      Oboe::API.start_trace('sequel_test', '', {}) do
        ps.call(:n=>'abc')
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "select_by_name"
      if RUBY_VERSION < "1.9"
        traces[1]['QueryArgs'].must_equal "abc"
      else
        traces[1]['QueryArgs'].must_equal "[\"abc\"]"
      end
      traces[1]['IsPreparedStatement'].must_equal "true"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end

    it 'should trace prep\'d stmnts and obey query privacy' do
      Oboe::Config[:sanitize_sql] = true
      ds = MYSQL_DB[:items].filter(:name=>:$n)
      ps = ds.prepare(:select, :select_by_name)

      Oboe::API.start_trace('sequel_test', '', {}) do
        ps.call(:n=>'abc')
      end

      traces = get_all_traces

      traces.count.must_equal 4
      validate_outer_layers(traces, 'sequel_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['Query'].must_equal "select_by_name"
      traces[1]['QueryArgs'].must_equal nil
      traces[1]['IsPreparedStatement'].must_equal "true"
      traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
      validate_event_keys(traces[2], @exit_kvs)
    end
  end
end
