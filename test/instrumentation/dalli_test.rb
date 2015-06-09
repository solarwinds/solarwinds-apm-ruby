require 'minitest_helper'

describe "Dalli" do
  before do
    clear_all_traces
    @dc = Dalli::Client.new
    @collect_backtraces = TraceView::Config[:dalli][:collect_backtraces]
  end

  after do
    TraceView::Config[:dalli][:collect_backtraces] = @collect_backtraces
  end

  it 'Stock Dalli should be loaded, defined and ready' do
    defined?(::Dalli).wont_match nil
    defined?(::Dalli::Client).wont_match nil
  end

  it 'should have traceview methods defined' do
    [ :perform_with_traceview, :get_multi_with_traceview].each do |m|
      ::Dalli::Client.method_defined?(m).must_equal true
    end
  end

  it 'should trace set' do
    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.set('some_key', 1234)
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'dalli_test')

    traces[1].has_key?("KVOp").must_equal true
    traces[1].has_key?("KVKey").must_equal true
    traces[1]['Layer'].must_equal "memcache"
    traces[1]['KVKey'].must_equal "some_key"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
  end

  it 'should trace get' do
    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.get('some_key')
    end

    traces = get_all_traces
    traces.count.must_equal 5

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "get"
    traces[1]['KVKey'].must_equal "some_key"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
    traces[2]['Label'].must_equal "info"
    traces[2].has_key?('KVHit').must_equal true
    traces[3]['Label'].must_equal "exit"
  end

  it 'should trace get_multi' do
    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.get_multi([:one, :two, :three, :four, :five, :six])
    end

    traces = get_all_traces
    traces.count.must_equal 5

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "get_multi"
    traces[2]['Label'].must_equal "info"
    traces[2]['RemoteHost'].must_equal "127.0.0.1:11211"
    traces[2].has_key?('KVKeyCount').must_equal true
    traces[2].has_key?('KVHitCount').must_equal true
    traces[3]['Label'].must_equal "exit"
  end

  it "should trace increment" do
    @dc.incr("dalli_key_counter", 1, nil, 0)

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.incr("dalli_key_counter")
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "incr"
    traces[1]['KVKey'].must_equal "dalli_key_counter"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
    traces[2]['Label'].must_equal "exit"
  end

  it "should trace decrement" do
    @dc.incr("dalli_key_counter", 1, nil, 0)

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.decr("dalli_key_counter")
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "decr"
    traces[1]['KVKey'].must_equal "dalli_key_counter"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
    traces[2]['Label'].must_equal "exit"
  end

  it "should trace replace" do
    @dc.set('some_key', 1)

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.replace("some_key", "woop")
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "replace"
    traces[1]['KVKey'].must_equal "some_key"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
    traces[2]['Label'].must_equal "exit"
  end

  it "should trace delete" do
    @dc.set('some_key', 1)

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.delete("some_key")
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'dalli_test')

    traces[1]['KVOp'].must_equal "delete"
    traces[1]['KVKey'].must_equal "some_key"
    traces[1]['RemoteHost'].must_equal "127.0.0.1:11211"
  end

  it "should obey :collect_backtraces setting when true" do
    @dc.set('some_key', 1)
    TraceView::Config[:dalli][:collect_backtraces] = true

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.get('some_key')
    end

    traces = get_all_traces
    layer_has_key(traces, 'memcache', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    TraceView::Config[:dalli][:collect_backtraces] = false

    TraceView::API.start_trace('dalli_test', '', {}) do
      @dc.get('some_key')
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'memcache', 'Backtrace')
  end
end
