# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe SolarWindsAPM::SDK do

  before do
    @trace_00 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
    @trace_01 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'

    SolarWindsAPM.config_lock.synchronize {
      @tm = SolarWindsAPM::Config[:tracing_mode]
      @sample_rate = SolarWindsAPM::Config[:sample_rate]
    }
    SolarWindsAPM::Config[:tracing_mode] = :enabled
    SolarWindsAPM::Config[:sample_rate] = 1000000

    # clean up because a test from a previous test files may not
    SolarWindsAPM.layer = nil
    SolarWindsAPM::Context.clear
  end

  after do
    SolarWindsAPM.config_lock.synchronize {
      SolarWindsAPM::Config[:tracing_mode] = @tm
      SolarWindsAPM::Config[:sample_rate] = @sample_rate
    }

    # need to do this, because we are stubbing log_end, which takes care of cleaning up
    SolarWindsAPM.layer = nil
    SolarWindsAPM::Context.clear
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  describe 'trace' do

    before do
      SolarWindsAPM::Context.fromString(@trace_01)
    end

    it 'should return the result from the block' do
      result = SolarWindsAPM::SDK.trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should log an entry, exception, and exit there is an exception' do
      SolarWindsAPM::API.expects(:log_entry)
      SolarWindsAPM::API.expects(:log_exception)
      SolarWindsAPM::API.expects(:log_exit)

      begin
        SolarWindsAPM::SDK.trace(:test) { raise StandardError }
      rescue
      end
    end

    it 'should not log if we are not sampling' do
      SolarWindsAPM::Context.fromString(@trace_00)
      SolarWindsAPM::API.expects(:log_event).never
      result = SolarWindsAPM::SDK.trace(:test) { 42 }
      assert_equal 42, result
    end

    it "should work without request_op parameter" do
      SolarWindsAPM::API.expects(:log_entry).twice
      SolarWindsAPM::API.expects(:log_exit).twice
      SolarWindsAPM::SDK.trace(:test) do
        SolarWindsAPM::SDK.trace(:test) {}
      end
    end

    it "should respect the request_op parameter" do
      # can't stub :log_entry, because it has the logic to record with the request_op parameter
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).once
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).once

      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') do
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test') do
          SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
        end
      end

      assert SolarWindsAPM.layer_op.empty? || SolarWindsAPM.layer_op.nil?
    end

    it "should work with sequential calls and an op paramter" do
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
    end

    it "should work with nested and sequential calls and an op param" do
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).once
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).once

      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') do
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
      end
    end

    it "should create spans for different ops" do
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') do
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test_2') {}
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test_2') {}
      end
    end

    it "should create a span if the ops are not sequential" do
      SolarWindsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      SolarWindsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      SolarWindsAPM::SDK.trace(:test, protect_op: 'test') do
        SolarWindsAPM::SDK.trace(:test, protect_op: 'test_2') do
          SolarWindsAPM::SDK.trace(:test, protect_op: 'test') {}
        end
      end
    end

    it 'should do the right thing in the recursive example' do
      def computation_with_sw_apm(n)
        SolarWindsAPM::SDK.trace('computation', kvs: { :number => n }, protect_op: :comp) do
          return n if n == 0
          n + computation_with_sw_apm(n - 1)
        end
      end

      SolarWindsAPM::API.expects(:log_event).with('computation', :entry, anything, anything).once
      SolarWindsAPM::API.expects(:log_event).with('computation', :exit, anything, anything).once

      computation_with_sw_apm(3)
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  describe 'start_trace single invocation' do
    it 'should log when sampling' do
      SolarWindsAPM::API.expects(:log_start).with('test_01', {}, {})
      SolarWindsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))

      result = SolarWindsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when sampling' do
      SolarWindsAPM::API.expects(:send_metrics).with('test_01', optionally(instance_of(Hash)))

      SolarWindsAPM::SDK.start_trace('test_01') {}
    end

    it 'should not log when NOT sampling' do
      SolarWindsAPM.config_lock.synchronize do
        SolarWindsAPM::Config[:tracing_mode] = :disabled
      end
      SolarWindsAPM::API.expects(:log_event).never

      result = SolarWindsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when NOT sampling' do
      SolarWindsAPM.config_lock.synchronize {
        SolarWindsAPM::Config[:tracing_mode] = :disabled
      }
      SolarWindsAPM::API.expects(:send_metrics)

      SolarWindsAPM::SDK.start_trace('test_01') { 42 }
    end

    it 'should not call log or metrics methods when there is a non-sampling context' do
      SolarWindsAPM::Context.fromString(@trace_00)

      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.expects(:send_metrics).never

      result = SolarWindsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should return the result from the block when there is a sampling context' do
      SolarWindsAPM::Context.fromString(@trace_01)

      result = SolarWindsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should call trace and not call log_start when there is a sampling context' do
      SolarWindsAPM::Context.fromString(@trace_01)

      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::API.expects(:send_metrics).never
      SolarWindsAPM::API.expects(:log_end).never
      SolarWindsAPM::SDK.expects(:trace).with('test_01', kvs: {})

      SolarWindsAPM::SDK.start_trace('test_01') { 42 }
    end

    it 'should log the tags when there is a sampling context' do
      SolarWindsAPM::Context.fromString(@trace_01)
      tags = { 'Spec' => 'rsc', 'RemoteURL' => 'https://asdf.com:1234/resource?id=5', 'IsService' => true }

      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::API.expects(:send_metrics).never
      SolarWindsAPM::API.expects(:log_end).never
      SolarWindsAPM::SDK.expects(:trace).with('test_01', kvs: tags)

      SolarWindsAPM::SDK.start_trace('test_01', kvs: tags) { 42 }
    end

    it 'should do metrics and not logging when there is an incoming non-sampling context' do
      SolarWindsAPM::API.expects(:log_event).never
      SolarWindsAPM::API.expects(:send_metrics)

      headers = { traceparent: @trace_01, tracestate: 'sw=123468dadadadada-00' }
      SolarWindsAPM::SDK.start_trace('test_01', headers: headers) { 42 }
    end

    it 'should send metrics when there is an incoming sampling context' do
      SolarWindsAPM::API.expects(:send_metrics)

      headers = { traceparent: @trace_01, tracestate: 'sw=123468dadadadada-01' }
      SolarWindsAPM::SDK.start_trace('test_01', headers: headers) { 42 }
    end

    it 'should continue traces' do
      clear_all_traces

      headers = { traceparent: @trace_01, tracestate: 'sw=123468dadadadada-01' }
      result = SolarWindsAPM::SDK.start_trace('test_01', headers: headers) { 42 }

      traces = get_all_traces
      assert_equal 42, result
      assert_equal 2, traces.size
      assert_equal 'entry', traces[0]['Label']
      assert_equal 'exit', traces[1]['Label']

      assert_equal SolarWindsAPM::TraceString.trace_id(@trace_01), SolarWindsAPM::TraceString.trace_id(traces[0]['sw.trace_context'])
      assert_equal '123468dadadadada', traces[0]['sw.parent_span_id'].downcase
    end

    it 'should use the transaction name from opts' do
      Time.expects(:now).returns(Time.at(0)).twice
      SolarWindsAPM::API.expects(:log_event).with('test_01', :entry, anything, Not(has_entry(:TransactionName => 'domain/this_name')))
      SolarWindsAPM::Span.expects(:createSpan).with('this_name', nil, 0, 0).returns('domain/this_name')
      SolarWindsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'domain/this_name'))

      result = SolarWindsAPM::SDK.start_trace('test_01', kvs: { :TransactionName => 'this_name' }) { 42 }
      assert_equal 42, result
    end

    it 'should overwrite the transaction name from opts' do
      Time.expects(:now).returns(Time.at(0)).twice
      SolarWindsAPM::API.expects(:log_event).with('test_01', :entry, anything, anything)
      SolarWindsAPM::Span.expects(:createSpan).with('custom_name_this_one', nil, 0, 0).returns('domain/custom_name_this_one')
      SolarWindsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'domain/custom_name_this_one'))
      sleep 0.1
      SolarWindsAPM::SDK.start_trace('test_01', kvs: { :TransactionName => 'custom_name' }) do
        SolarWindsAPM::SDK.set_transaction_name('custom_name_this_one')
      end
    end

    it 'should call createSpan and log_end in case of an exception' do
      Time.expects(:now).returns(Time.at(0)).twice
      SolarWindsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0, 0).returns('domain/custom-test_01')
      SolarWindsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'domain/custom-test_01'), instance_of(Oboe_metal::Event))
      begin
        SolarWindsAPM::SDK.start_trace('test_01') do
          raise StandardError
        end
      rescue StandardError
      end
    end

    it 'should report duration correctly when there is an exception' do
      SolarWindsAPM::API.expects(:log_exception).once
      SolarWindsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 42000000, 0)
      Time.expects(:now).returns(Time.at(0))
      begin
        SolarWindsAPM::SDK.start_trace('test_01') do
          Time.expects(:now).returns(Time.at(42))
          raise StandardError
        end
      rescue StandardError
      end
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  describe 'start_trace nested invocation' do
    it 'should call send_metrics only once' do
      SolarWindsAPM::API.expects(:send_metrics).once
      sleep 0.1
      SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.start_trace('test_02') { sleep 0.1 }
      end
    end

    it 'should use the outer layer name' do
      SolarWindsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))
      SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the opts from the first call to start_trace for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      SolarWindsAPM::Span.expects(:createSpan).with('custom_name', nil, 0, 0)

      SolarWindsAPM::SDK.start_trace('test_01', kvs: { :TransactionName => 'custom_name' }) do
        SolarWindsAPM::SDK.start_trace('test_02', kvs: { :TransactionName => 'custom_name_02' }) { 42 }
      end
    end

    it 'should NOT use the opts from the second call to start_trace for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      SolarWindsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0, 0)

      SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.start_trace('test_02', kvs: { :TransactionName => 'custom_name_02' }) { 42 }
      end
    end

    it 'should use the last assigned transaction name' do
      Time.expects(:now).returns(Time.at(0)).times(4)
      SolarWindsAPM::Span.expects(:createSpan).with('actually_this_one', nil, 0, 0)
      SolarWindsAPM::Span.expects(:createSpan).with('actually_this_one_as_well', nil, 0, 0)

      SolarWindsAPM::SDK.start_trace('test_01', kvs: { :TransactionName => 'custom_name' }) do
        SolarWindsAPM::SDK.set_transaction_name('this_one')
        SolarWindsAPM::SDK.start_trace('test_02', kvs: { :TransactionName => 'custom_name_02' }) do
          SolarWindsAPM::SDK.set_transaction_name('actually_this_one')
        end
      end

      SolarWindsAPM::SDK.start_trace('test_01', kvs: { :TransactionName => 'custom_name' }) do
        SolarWindsAPM::SDK.start_trace('test_02', kvs: { :TransactionName => 'custom_name_02' }) do
          SolarWindsAPM::SDK.set_transaction_name('this_one')
        end
        SolarWindsAPM::SDK.set_transaction_name('actually_this_one_as_well')
      end
    end

    it 'should return the result from the inner block' do
      result = SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.start_trace('test_02') { 42 }
      end

      assert_equal 42, result
    end

    it 'should use the outer layer name in case of an exception' do
      SolarWindsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))
      begin
        SolarWindsAPM::SDK.start_trace('test_01') do
          SolarWindsAPM::SDK.start_trace('test_02') do
            raise StandardError
          end
        end
      rescue StandardError
      end
    end

  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  describe 'start_trace_with_target' do
    it 'should assign an X-Trace header to target' do
      target = {}
      SolarWindsAPM::SDK.start_trace_with_target('test_01', target: target) {}

      assert SolarWindsAPM::TraceString.valid?(target['X-Trace'])
    end

    it 'should call trace and not call log_start when there is a sampling context' do
      target = { 'test' => true }
      SolarWindsAPM::Context.fromString(@trace_01)

      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::Span.expects(:createSpan).never
      SolarWindsAPM::API.expects(:log_end).never
      SolarWindsAPM::SDK.expects(:trace).with('test_01', kvs: {})

      SolarWindsAPM::SDK.start_trace_with_target('test_01', target: target) {}
    end

    it 'should call trace and not call log_start when there is a non-sampling context' do
      target = { :test => true }
      SolarWindsAPM::Context.fromString(@trace_00)

      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::Span.expects(:createSpan).never
      SolarWindsAPM::API.expects(:log_end).never
      SolarWindsAPM::SDK.expects(:trace).with('test_01', kvs: {})

      SolarWindsAPM::SDK.start_trace_with_target('test_01', target: target) { 42 }
    end

    it 'should return the result from the block when there is a non-sampling context ttt' do
      target = { :test => true }
      SolarWindsAPM::Context.fromString(@trace_00)

      result = SolarWindsAPM::SDK.start_trace_with_target('test_01', target: target) { 42 }
      assert_equal 42, result
    end
  end

  describe 'TraceMethod' do
    before do
      clear_all_traces
    end

    after do
      clear_all_traces
      SolarWindsAPM::Context.clear
    end

    it 'traces an instance method' do
      def to_be_traced(a, b)
        a + b
      end

      SolarWindsAPM::SDK.trace_method(self.class, :to_be_traced)

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        result = to_be_traced(3, 5)
        _(result).must_equal 8
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'to_be_traced'
      _(traces[1]['Class']).must_equal 'SolarWindsAPM::SDK::TraceMethod'
      _(traces[1]['MethodName']).must_equal 'to_be_traced'

    end

    it 'traces an instance method with a block' do
      def to_be_traced_with_block(a, b, &block)
        c = block.call
        a + b + c
      end

      SolarWindsAPM::SDK.trace_method(self.class, :to_be_traced_with_block)

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        result = to_be_traced_with_block(3, 5) { 8 }
        _(result).must_equal 16
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'to_be_traced_with_block'
    end

    it 'respects the opts when it traces an instance method' do
      def to_be_traced_2
        1 + 1
      end

      SolarWindsAPM::SDK.trace_method(self.class, :to_be_traced_2, config: { name: 'i_am_traced', backtrace: true })

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        to_be_traced_2
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'i_am_traced'
      _(traces[1]['Class']).must_equal 'SolarWindsAPM::SDK::TraceMethod'
      _(traces[1]['MethodName']).must_equal 'to_be_traced_2'
      _(traces[2]['Backtrace']).wont_be_nil
    end

    it 'warns if we try to instrument an instance method twice' do
      SolarWindsAPM.logger.expects(:warn).with(regexp_matches(/already instrumented/))

      def to_be_traced_3
        1 + 1
      end

      SolarWindsAPM::SDK.trace_method(self.class, :to_be_traced_3)
      SolarWindsAPM::SDK.trace_method(self.class, :to_be_traced_3)
    end

    it 'traces a class method' do
      module ::TopTest
        def self.to_be_traced_4(a, b)
          a + b
        end
      end

      SolarWindsAPM::SDK.trace_method(::TopTest, :to_be_traced_4)

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        result = ::TopTest.to_be_traced_4(5, 7)
        _(result).must_equal 12
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'to_be_traced_4'
      _(traces[1]['Module']).must_equal 'TopTest'
      _(traces[1]['MethodName']).must_equal 'to_be_traced_4'
    end

    it 'traces a class method with a block' do
      module ::TopTest
        def self.to_be_traced_with_block_2(a, b, &block)
          c = block.call
          a + b + c
        end
      end

      SolarWindsAPM::SDK.trace_method(::TopTest, :to_be_traced_with_block_2)

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        result = ::TopTest.to_be_traced_with_block_2(5, 7) { 12 }
        _(result).must_equal 24
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'to_be_traced_with_block_2'
    end

    it 'respects the opts when it traces a class method' do
      module ::TopTest
        def self.to_be_traced_5
          1 + 1
        end
      end

      SolarWindsAPM::SDK.trace_method(::TopTest, :to_be_traced_5, config: { name: 'i_am_traced', backtrace: true })

      SolarWindsAPM::SDK.start_trace('trace_test_01') do
        ::TopTest.to_be_traced_5
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'i_am_traced'
      _(traces[1]['Module']).must_equal 'TopTest'
      _(traces[1]['MethodName']).must_equal 'to_be_traced_5'
      _(traces[2]['Backtrace']).wont_be_nil
    end

    it 'warns if we try to instrument a class method twice' do
      SolarWindsAPM.logger.expects(:warn).with(regexp_matches(/already instrumented/))

      module ::TopTest
        def self.to_be_traced_6
          1 + 1
        end
      end

      SolarWindsAPM::SDK.trace_method(::TopTest, :to_be_traced_6)
      SolarWindsAPM::SDK.trace_method(::TopTest, :to_be_traced_6)
    end

  end

  describe 'log events' do
    before do
      clear_all_traces
    end

    after do
      clear_all_traces
      SolarWindsAPM::Context.clear
    end

    it 'SDK should log exceptions' do
      SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.log_exception(StandardError.new, { the: 'exception' })
      end

      traces = get_all_traces
      _(traces.size).must_equal 3

      _(traces[1]['Label']).must_equal 'error'
      _(traces[1]['the']).must_equal 'exception'
    end

    it 'SDK should log info' do
      SolarWindsAPM::SDK.start_trace('test_01') do
        SolarWindsAPM::SDK.log_info({ the: 'information' })
      end

      traces = get_all_traces
      _(traces.size).must_equal 3

      _(traces[1]['Label']).must_equal 'info'
      _(traces[1]['the']).must_equal 'information'
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  describe 'set_transaction_name' do
    it 'should not set the transaction name if the arg is not a string or an empty string' do
      SolarWindsAPM.transaction_name = nil

      SolarWindsAPM::SDK.set_transaction_name(123)
      assert_nil SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name('')
      assert_nil SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name(String.new)
      assert_nil SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name(false)
      assert_nil SolarWindsAPM.transaction_name
    end

    it 'should return the previous name, if a non-valid one is given' do
      SolarWindsAPM::SDK.set_transaction_name("this is the one")

      SolarWindsAPM::SDK.set_transaction_name(123)
      assert_equal "this is the one", SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name('')
      assert_equal "this is the one", SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name(String.new)
      assert_equal "this is the one", SolarWindsAPM.transaction_name

      SolarWindsAPM::SDK.set_transaction_name(false)
      assert_equal "this is the one", SolarWindsAPM.transaction_name

      SolarWindsAPM.transaction_name = nil
    end
  end

  describe 'tracing?' do
    it 'should return false if we are not tracing' do
      SolarWindsAPM::Context.fromString(@trace_00)
      refute SolarWindsAPM::SDK.tracing?
    end

    it 'should return true if we are tracing' do
      SolarWindsAPM::Context.fromString(@trace_01)
      assert SolarWindsAPM::SDK.tracing?
    end

    it 'should return false if the context is invalid' do
      SolarWindsAPM::Context.fromString('2BB05F01')
      sleep 0.1
      refute SolarWindsAPM::SDK.tracing?
    end
  end

  describe 'solarwinds_ready?' do
    it 'should return true if it can connect' do
      SolarWindsAPM::Context.expects(:isReady).with(10_000).returns(1)
      assert SolarWindsAPM::SDK.solarwinds_ready?(10_000)
    end

    it 'should work with no arg' do
      SolarWindsAPM::Context.expects(:isReady).returns(1)
      assert SolarWindsAPM::SDK.solarwinds_ready?
    end

    it 'should return false if it cannot connect' do
      SolarWindsAPM::Context.expects(:isReady).returns(2)
      refute SolarWindsAPM::SDK.solarwinds_ready?
    end
  end

  describe 'createSpan' do
    # Let's test the return value of createSpan a bit too
    it 'should return a transaction name' do
      assert_equal 'my_name', SolarWindsAPM::Span.createSpan('my_name', nil, 0, 0)
      assert_equal 'unknown', SolarWindsAPM::Span.createSpan(nil, nil, 0, 0)
      assert_equal 'unknown', SolarWindsAPM::Span.createSpan('', nil, 0, 0)
      assert_equal 'domain/my_name', SolarWindsAPM::Span.createSpan('my_name', 'domain', 0, 0)
    end
  end
end
