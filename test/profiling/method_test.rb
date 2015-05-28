require 'minitest_helper'

describe "TraceViewMethodProfiling" do
  before do
    clear_all_traces
    # Conditionally Undefine TestWorker
    # http://stackoverflow.com/questions/11503558/how-to-undefine-class-in-ruby
    Object.send(:remove_const, :TestWorker) if defined?(TestWorker)
  end

  it 'should be loaded, defined and ready' do
    defined?(::TraceViewMethodProfiling).wont_match nil
  end

  it 'should trace Class methods' do
    class TestWorker
      def self.do_work
        sleep 1
      end

      class << self
        include TraceViewMethodProfiling
        profile_method :do_work, 'do_work'
      end
    end

    ::TraceView::API.start_trace('method_profiling', '', {}) do
      # Call the profiled class method
      TestWorker.do_work
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'method_profiling')

    kvs = {}
    kvs["Label"] = 'profile_entry'
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"
    kvs["FunctionName"] = "do_work"
    kvs["Class"] = "TestWorker"

    validate_event_keys(traces[1], kvs)

    traces[1].has_key?("Layer").must_equal false
    traces[1].has_key?("File").must_equal true
    traces[1].has_key?("LineNumber").must_equal true

    kvs.clear
    kvs["Label"] = "profile_exit"
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"

    validate_event_keys(traces[2], kvs)
    traces[2].has_key?("Layer").must_equal false
  end

  it 'should trace Instance methods' do
    class TestWorker
      def do_work
        sleep 1
      end

      include TraceViewMethodProfiling
      profile_method :do_work, 'do_work'
    end

    ::TraceView::API.start_trace('method_profiling', '', {}) do
      # Call the profiled class method
      tw = TestWorker.new
      tw.do_work
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'method_profiling')

    kvs = {}
    kvs["Label"] = 'profile_entry'
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"
    kvs["FunctionName"] = "do_work"
    kvs["Class"] = "TestWorker"

    validate_event_keys(traces[1], kvs)

    traces[1].has_key?("Layer").must_equal false
    traces[1].has_key?("File").must_equal true
    traces[1].has_key?("LineNumber").must_equal true

    kvs.clear
    kvs["Label"] = "profile_exit"
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"

    validate_event_keys(traces[2], kvs)
    traces[2].has_key?("Layer").must_equal false
  end

  it 'should trace Module class methods' do
    module TestWorker
      def self.do_work
        sleep 1
      end

      class << self
        include TraceViewMethodProfiling
        profile_method :do_work, 'do_work'
      end
    end

    ::TraceView::API.start_trace('method_profiling', '', {}) do
      # Call the profiled class method
      TestWorker.do_work
    end

    traces = get_all_traces
    traces.count.must_equal 4
    validate_outer_layers(traces, 'method_profiling')

    kvs = {}
    kvs["Label"] = 'profile_entry'
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"
    kvs["FunctionName"] = "do_work"
    kvs["Module"] = "TestWorker"

    validate_event_keys(traces[1], kvs)

    traces[1].has_key?("Layer").must_equal false
    traces[1].has_key?("File").must_equal true
    traces[1].has_key?("LineNumber").must_equal true

    kvs.clear
    kvs["Label"] = "profile_exit"
    kvs["Language"] = "ruby"
    kvs["ProfileName"] = "do_work"

    validate_event_keys(traces[2], kvs)
    traces[2].has_key?("Layer").must_equal false
  end

  it 'should not store arguments and return value by default' do
    class TestWorker
      def self.do_work(s, i, a, h)
        sleep 1
        return "the zebra is loose"
      end

      class << self
        include TraceViewMethodProfiling
        # Default call method
        profile_method :do_work, 'do_work'
      end
    end

    ::TraceView::API.start_trace('method_profiling', '', {}) do
      # Call the profiled class method
      TestWorker.do_work('String Argument', 203984, ["1", "2", 3], { :color => :black })
    end

    traces = get_all_traces
    traces.count.must_equal 4

    traces[1].has_key?("Args").must_equal false
    traces[2].has_key?("ReturnValue").must_equal false
  end

  it 'should store arguments and return value when asked' do
    class TestWorker
      def self.do_work(s, i, a, h)
        sleep 1
        return "the zebra is loose"
      end

      class << self
        include TraceViewMethodProfiling
        profile_method :do_work, 'do_work', true, true
      end
    end

    ::TraceView::API.start_trace('method_profiling', '', {}) do
      # Call the profiled class method
      TestWorker.do_work('String Argument', 203984, ["1", "2", 3], { :color => :black })
    end

    traces = get_all_traces
    traces.count.must_equal 4

    traces[1].has_key?("Args").must_equal true
    traces[1]["Args"].must_equal "\"String Argument\"\n203984\n[\"1\", \"2\", 3]\n{:color=>:black}\n"

    traces[2].has_key?("ReturnValue").must_equal true
    traces[2]["ReturnValue"].must_equal "\"the zebra is loose\"\n"
  end
end
