require 'minitest_helper'

if (RUBY_VERSION =~ /^1./) == 0
  describe Oboe::Inst::Memcached do
    require 'memcached'
    require 'memcached/rails'
  
    before do
      clear_all_traces 
      @mc = ::Memcached::Rails.new(:servers => ['localhost'])

      # These are standard entry/exit KVs that are passed up with all mongo operations
      @entry_kvs = {
        'Layer' => 'memcache',
        'Label' => 'entry' }

      @info_kvs = {
        'Layer' => 'memcache',
        'Label' => 'info' }

      @exit_kvs = { 'Layer' => 'memcache', 'Label' => 'exit' }
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
      
      traces[1]['KVOp'].must_equal "set"
      traces[1]['KVKey'].must_equal "testKey"
      traces[1].has_key?('Backtrace').must_equal false

      validate_event_keys(traces[2], @exit_kvs)
    end
    
    it "should trace get" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.get('msg')
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 4
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      
      traces[1]['KVOp'].must_equal "get"
      traces[1]['KVKey'].must_equal "msg"
      traces[1].has_key?('Backtrace').must_equal false
      
      validate_event_keys(traces[2], @exit_kvs)
    end
    
    it "should trace get_multi" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.get_multi(['one', 'two', 'three', 'four', 'five', 'six'])
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 5
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      
      traces[1]['KVOp'].must_equal "get_multi"
      traces[1].has_key?('Backtrace').must_equal false
      
      validate_event_keys(traces[2], @info_kvs)
      traces[2]['KVKeyCount'].must_equal "6"
      traces[2].has_key?('KVHitCount').must_equal true
      traces[2].has_key?('Backtrace').must_equal false

      validate_event_keys(traces[3], @exit_kvs)
    end
    
    it "should trace add for existing key" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.add('testKey', 'x', 1200)
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 5
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      
      traces[1]['KVOp'].must_equal "add"
      traces[1]['KVKey'].must_equal "testKey"
      traces[1].has_key?('Backtrace').must_equal false
      
      traces[2]['ErrorClass'].must_equal "Memcached::NotStored"
      traces[2]['Message'].must_equal "Memcached::NotStored"
      traces[2]['Backtrace'].must_equal ""
      
      validate_event_keys(traces[3], @exit_kvs)
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
      
      traces[1]['KVOp'].must_equal "append"
      traces[1]['KVKey'].must_equal "rawKey"
      traces[1].has_key?('Backtrace').must_equal false
      
      validate_event_keys(traces[2], @exit_kvs)
    end
    
    it "should trace decr" do
      @mc.set('rawKey', "Peanut Butter ", 600, :raw => true)
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.append('rawKey', "Jelly")
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 4
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      
      traces[1]['KVOp'].must_equal "append"
      traces[1]['KVKey'].must_equal "rawKey"
      traces[1].has_key?('Backtrace').must_equal false
      
      validate_event_keys(traces[2], @exit_kvs)
    end
  
    it "should trace increment" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @mc.incr("some_key_counter", 1, nil, 0)
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 4
      validate_outer_layers(traces, 'memcached_test')
      
      validate_event_keys(traces[1], @entry_kvs)

      traces[1]['KVOp'].must_equal "incr"
      traces[1]['KVKey'].must_equal "some_key_counter"
      
      validate_event_keys(traces[2], @exit_kvs)
    end
  
    it "should trace replace" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @dc.replace("some_key", "woop")
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 4
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['KVOp'].must_equal "replace"
      traces[1]['KVKey'].must_equal "some_key"
      validate_event_keys(traces[2], @exit_kvs)
    end

    it "should trace delete" do
      Oboe::API.start_trace('memcached_test', '', {}) do
        @dc.delete("some_key")
      end
      
      traces = get_all_traces
      
      traces.count.must_equal 4
      validate_outer_layers(traces, 'memcached_test')

      validate_event_keys(traces[1], @entry_kvs)
      traces[1]['KVOp'].must_equal "delete"
      traces[1]['KVKey'].must_equal "some_key"
      validate_event_keys(traces[2], @exit_kvs)
    end
  end
end
