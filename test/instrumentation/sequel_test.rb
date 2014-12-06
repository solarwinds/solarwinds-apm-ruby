require 'minitest_helper'

if ENV.key?('TRAVIS_PSQL_PASS')
  DB = Sequel.connect("postgres://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test")
else
  DB = Sequel.connect('postgres://postgres@127.0.0.1:5432/travis_ci_test')
end

unless DB.table_exists?(:items)
  DB.create_table :items do
    primary_key :id
    String :name
    Float :price
  end
end

describe Oboe::Inst::Sequel do
  before do
    clear_all_traces

    # These are standard entry/exit KVs that are passed up with all sequel operations
    @entry_kvs = {
      'Layer' => 'sequel',
      'Label' => 'entry',
      'Database' => 'travis_ci_test',
      'RemoteHost' => '127.0.0.1',
      'RemotePort' => '5432' }

    @exit_kvs = { 'Layer' => 'sequel', 'Label' => 'exit' }
    @collect_backtraces = Oboe::Config[:sequel][:collect_backtraces]
  end

  after do
    Oboe::Config[:sequel][:collect_backtraces] = @collect_backtraces
  end

  it 'Stock sequel should be loaded, defined and ready' do
    defined?(::Sequel).wont_match nil
  end

  it 'sequel should have oboe methods defined' do
    #::Sequel::Database
    ::Sequel::Database.method_defined?(:extract_trace_details).must_equal true
    ::Sequel::Database.method_defined?(:run_with_oboe).must_equal true
    ::Sequel::Database.method_defined?(:get_with_oboe).must_equal true
    ::Sequel::Database.method_defined?(:execute_dui_with_oboe).must_equal true
  end

  it 'should trace DB.run' do
    Oboe::API.start_trace('sequel_test', '', {}) do
      DB.run("select 1")
    end

    traces = get_all_traces
    traces.count.must_equal 4
    validate_outer_layers(traces, 'sequel_test')

    validate_event_keys(traces[1], @entry_kvs)
    traces[1]['Query'].must_equal "select 1"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:sequel][:collect_backtraces]
    validate_event_keys(traces[2], @exit_kvs)
  end

  it "should obey :collect_backtraces setting when true" do
    Oboe::Config[:sequel][:collect_backtraces] = true

    Oboe::API.start_trace('sequel_test', '', {}) do
      if ENV.key?('TRAVIS_PSQL_PASS')
        DB = Sequel.connect("postgres://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test")
      else
        DB = Sequel.connect('postgres://postgres@127.0.0.1:5432/travis_ci_test')
      end
      DB.run('select 1')
    end

    traces = get_all_traces
    layer_has_key(traces, 'sequel', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    Oboe::Config[:sequel][:collect_backtraces] = false

    Oboe::API.start_trace('sequel_test', '', {}) do
      if ENV.key?('TRAVIS_PSQL_PASS')
        DB = Sequel.connect("postgres://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test")
      else
        DB = Sequel.connect('postgres://postgres@127.0.0.1:5432/travis_ci_test')
      end
      DB.run('select 1')
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'sequel', 'Backtrace')
  end
end
