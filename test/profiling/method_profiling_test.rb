# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.
require 'minitest_helper'

# TV Method profiling only supports Ruby 1.9.3 or greater.  For earlier Ruby versions
# see the legacy method profiling in lib/traceview/legacy_method_profiling.rb.
if RUBY_VERSION >= '1.9.3'
  describe "TraceViewMethodProfiling" do
    before do
      clear_all_traces
      # Conditionally Undefine TestWorker
      # http://stackoverflow.com/questions/11503558/how-to-undefine-class-in-ruby
      Object.send(:remove_const, :TestKlass) if defined?(TestKlass)
      Object.send(:remove_const, :TestModule) if defined?(TestModule)
    end

    it 'should be loaded, defined and ready' do
      defined?(::TraceView::MethodProfiling).wont_match nil
      assert_equal true, TraceView::API.respond_to?(:profile_method), "has profile_method method"
    end

    it 'should return false for bad arguments' do
      class TestKlass
        def do_work
          return 687
        end
      end

      # Bad first param
      rv = TraceView::API.profile_method('blah', :do_work)
      assert_equal false, rv, "Return value must be false for bad args"

      # Bad first param
      rv = TraceView::API.profile_method(TestKlass, 52)
      assert_equal false, rv, "Return value must be false for bad args"
    end

    it 'should profile class instance methods' do
      class TestKlass
        def do_work
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      result = nil

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        result = TestKlass.new.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should not double profile already profiled methods' do
      class TestKlass
        def do_work
          return 687
        end
      end

      # Attempt to double profile
      rv = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, rv, "Return value must be true"

      rv = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal false, rv, "Return value must be false"

      with_tv = TestKlass.instance_methods.select{ |m| m == :do_work_with_traceview }
      assert_equal with_tv.count, 1, ":do_work_with_traceview method count"

      without_tv = TestKlass.instance_methods.select{ |m| m == :do_work_without_traceview }
      assert_equal without_tv.count, 1, ":do_work_without_traceview method count"
    end

    it 'should error out for non-existent methods' do
      class TestKlass
        def do_work
          return 687
        end
      end

      rv = TraceView::API.profile_method(TestKlass, :does_not_exist)
      assert_equal false, rv, "Return value must be false"

      with_tv = TestKlass.instance_methods.select{ |m| m == :does_not_exit_with_traceview }
      assert_equal with_tv.count, 0, ":does_not_exit_with_traceview method count"

      without_tv = TestKlass.instance_methods.select{ |m| m == :does_not_exit_without_traceview }
      assert_equal without_tv.count, 0, ":does_not_exit_without_traceview method count"
    end

    it 'should trace class singleton methods' do
      class TestKlass
        def self.do_work
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        result = TestKlass.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should trace class private instance methods' do
      class TestKlass
        private
        def do_work
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      result = nil

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        result = TestKlass.new.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should trace class private singleton methods' do
      class TestKlass
        private
        def self.do_work
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        result = TestKlass.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should trace module singleton methods' do
      module TestModule
        def self.do_work
          sleep 1
          return 687
        end
      end

      result = TraceView::API.profile_method(TestModule, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        result = TestModule.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Module"] = "TestModule"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should trace module instance methods' do
      module TestModule
        def do_work
          sleep 1
          return 687
        end
      end

      # Profile the module before including in a class
      result = TraceView::API.profile_method(TestModule, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      class TestKlass
        include TestModule
      end

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        result = TestKlass.new.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Module"] = "TestModule"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should profile methods that use blocks' do
      class TestKlass
        def self.do_work(&block)
          yield
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        result = TestKlass.do_work do
          787
        end
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 787

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false
    end

    it 'should profile methods with various argument types' do
      skip
    end

    it 'should not store arguments and return value by default' do
      class TestKlass
        def do_work(blah = {})
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work)
      assert_equal true, result, "profile_method return value must be true"

      result = nil

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        result = TestKlass.new.do_work(:ok => :blue)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false

      traces[2].key?("Arguments").must_equal false
      traces[2].key?("ReturnValue").must_equal false
    end

    it 'should store arguments and return value when asked' do
      class TestKlass
        def do_work(blah = {})
          return 687
        end
      end

      result = TraceView::API.profile_method(TestKlass, :do_work, true, true)
      assert_equal true, result, "profile_method return value must be true"

      result = nil

      ::TraceView::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        result = TestKlass.new.do_work(:ok => :blue)
      end

      traces = get_all_traces
      traces.count.must_equal 4
      assert valid_edges?(traces), "Trace edge validation"

      validate_outer_layers(traces, 'method_profiling')

      result.must_equal 687

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["Class"] = "TestKlass"

      validate_event_keys(traces[1], kvs)

      traces[1].key?("Layer").must_equal false
      traces[1].key?("File").must_equal true
      traces[1].key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].key?("Layer").must_equal false

      traces[2].key?("Arguments").must_equal true
      traces[2]["Arguments"].must_equal "[{:ok=>:blue}]"

      traces[2].key?("ReturnValue").must_equal true
      traces[2]["ReturnValue"].must_equal 687
    end
  end
end
