require 'minitest_helper'

if RUBY_VERSION < '2.0' and not defined?(JRUBY_VERSION)
  describe Oboe::Inst::Memcached do
    require 'memcached'
    require 'memcached/rails'

    before do
      clear_all_traces
      @mc = ::Memcached::Rails.new(:servers => ['127.0.0.1'])

      # These are standard entry/exit KVs that are passed up with all mongo operations
      @entry_kvs = {
        'Layer' => 'memcache',
        'Label' => 'entry' }

      @info_kvs = {
        'Layer' => 'memcache',
        'Label' => 'info' }

      @exit_kvs = { 'Layer' => 'memcache', 'Label' => 'exit' }
      @collect_backtraces = Oboe::Config[:memcached][:collect_backtraces]
    end

    after do
      Oboe::Config[:memcached][:collect_backtraces] = @collect_backtraces
    end

    it 'Stock Memcached should be loaded, defined and ready' do
      defined?(::Memcached).wont_match nil
      defined?(::Memcached::Rails).wont_match nil
    end

    it 'Memcached should have oboe methods defined' do
      Oboe::API::Memcache::MEMCACHE_OPS.each do |m|
        if ::Memcached.method_defined?(m)
          ::Memcached.method_defined?("#{m}_with_oboe").must_equal true
        end
        ::Memcached::Rails.method_defined?(:get_multi_with_oboe).must_equal true
      end
    end

    it "should trace set" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.set('testKey', 'blah')
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "set"
      traces[1]['KVKey'].must_equal "testKey"
    end

    it "should trace get" do
      @mc.set('testKey', 'blah')

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.get('testKey')
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "get"
      traces[1]['KVKey'].must_equal "testKey"
    end

    it "should trace get_multi" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.get_multi(['one', 'two', 'three', 'four', 'five', 'six'])
      end

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @info_kvs)
      validate_event_keys(traces[3], @exit_kvs)

      traces[1]['KVOp'].must_equal "get_multi"

      traces[2]['KVKeyCount'].must_equal "6"
      traces[2].has_key?('KVHitCount').must_equal true
    end

    it "should trace add for existing key" do
      @mc.set('testKey', 'x', 1200)

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.add('testKey', 'x', 1200)
      end

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[3], @exit_kvs)

      traces[1]['KVOp'].must_equal "add"
      traces[1]['KVKey'].must_equal "testKey"

      traces[2]['ErrorClass'].must_equal "Memcached::NotStored"
      traces[2]['Message'].must_equal "Memcached::NotStored"
    end

    it "should trace append" do
      @mc.set('rawKey', "Peanut Butter ", 600, :raw => true)
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.append('rawKey', "Jelly")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "append"
      traces[1]['KVKey'].must_equal "rawKey"
    end

    it "should trace decr" do
      @mc.set('some_key_counter', "100", 0, false)

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.decr('some_key_counter', 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "decr"
      traces[1]['KVKey'].must_equal "some_key_counter"
    end

    it "should trace increment" do
      @mc.set('some_key_counter', "100", 0, false)

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.incr("some_key_counter", 1)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "incr"
      traces[1]['KVKey'].must_equal "some_key_counter"
    end

    it "should trace replace" do
      @mc.set('some_key', 'blah')
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.replace("some_key", "woop")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "replace"
      traces[1]['KVKey'].must_equal "some_key"
    end

    it "should trace delete" do
      @mc.set('some_key', 'blah')
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.delete("some_key")
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'memcached_test')
      validate_event_keys(traces[1], @entry_kvs)
      validate_event_keys(traces[2], @exit_kvs)

      traces[1]['KVOp'].must_equal "delete"
      traces[1]['KVKey'].must_equal "some_key"
    end

    it "should obey :collect_backtraces setting when true" do
      Oboe::Config[:memcached][:collect_backtraces] = true

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.set('some_key', 1)
      end

      traces = get_all_traces
      layer_has_key(traces, 'memcache', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      Oboe::Config[:memcached][:collect_backtraces] = false

      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.set('some_key', 1)
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'memcache', 'Backtrace')
    end
  end
end
