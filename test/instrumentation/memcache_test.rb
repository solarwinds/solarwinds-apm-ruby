require 'minitest_helper'
require 'memcache'

describe Oboe::API::Memcache do
  before do
    clear_all_traces 
    @mc = ::MemCache.new('localhost')

    # These are standard entry/exit KVs that are passed up with all mongo operations
    @entry_kvs = {
      'Layer' => 'memcache',
      'Label' => 'entry' }

    @info_kvs = {
      'Layer' => 'memcache',
      'Label' => 'info' }

    @exit_kvs = { 'Layer' => 'memcache', 'Label' => 'exit' }
  end

  it 'Stock MemCache should be loaded, defined and ready' do
    defined?(::MemCache).wont_match nil 
  end

  it 'MemCache should have oboe methods defined' do
    Oboe::API::Memcache::MEMCACHE_OPS.each do |m|
      if ::MemCache.method_defined?(m)
        ::MemCache.method_defined?("#{m}_with_oboe").must_equal true 
      end
      ::MemCache.method_defined?(:request_setup_with_oboe).must_equal true 
      ::MemCache.method_defined?(:cache_get_with_oboe).must_equal true 
      ::MemCache.method_defined?(:get_multi_with_oboe).must_equal true 
    end
  end
  
  it "should trace set" do
    Oboe::API.start_trace('memcache_test', '', {}) do
      @mc.set('msg', 'blah')
    end
    
    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    
    traces[1]['KVOp'].must_equal "set"
    traces[1].has_key?('Backtrace').must_equal false
    
    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "msg"
    traces[2].has_key?('Backtrace').must_equal false

    validate_event_keys(traces[3], @exit_kvs)
  end
  
  it "should trace get" do
    Oboe::API.start_trace('memcache_test', '', {}) do
      @mc.get('msg')
    end
    
    traces = get_all_traces
    
    traces.count.must_equal 6
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    
    traces[1]['KVOp'].must_equal "get"
    traces[1].has_key?('Backtrace').must_equal false
    
    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "msg"
    traces[2]['RemoteHost'].must_equal "localhost"
    traces[2].has_key?('Backtrace').must_equal false

    traces[3].has_key?('KVHit').must_equal true
    traces[3].has_key?('Backtrace').must_equal false

    validate_event_keys(traces[4], @exit_kvs)
  end
  
  it "should trace get_multi" do
    Oboe::API.start_trace('memcache_test', '', {}) do
      @mc.get_multi(['one', 'two', 'three', 'four', 'five', 'six'])
    end
    
    traces = get_all_traces
    
    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    
    traces[1]['KVOp'].must_equal "get_multi"
    traces[1].has_key?('Backtrace').must_equal false
    
    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKeyCount'].must_equal "6"
    traces[2].has_key?('KVHitCount').must_equal true
    traces[2].has_key?('Backtrace').must_equal false

    validate_event_keys(traces[3], @exit_kvs)
  end
end
