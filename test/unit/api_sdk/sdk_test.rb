# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe AppOpticsAPM::SDK do

  before do
    AppOpticsAPM.config_lock.synchronize {
      @tm = AppOpticsAPM::Config[:tracing_mode]
      @sample_rate = AppOpticsAPM::Config[:sample_rate]
    }
    AppOpticsAPM::Config[:tracing_mode] = :enabled
    AppOpticsAPM::Config[:sample_rate] = 1000000
  end

  after do
    AppOpticsAPM.config_lock.synchronize {
      AppOpticsAPM::Config[:tracing_mode] = @tm
      AppOpticsAPM::Config[:sample_rate] = @sample_rate
    }

    # need to do this, because we are stubbing log_end, which takes care of cleaning up
    AppOpticsAPM.layer = nil
    AppOpticsAPM::Context.clear
  end


  describe 'trace' do
    before do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')
    end

    it 'should return the result from the block' do
      result = AppOpticsAPM::SDK.trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should log an entry, exception, and exit there is an exception' do
      AppOpticsAPM::API.expects(:log_entry)
      AppOpticsAPM::API.expects(:log_exception)
      AppOpticsAPM::API.expects(:log_exit)

      begin
        AppOpticsAPM::SDK.trace(:test) { raise StandardError }
      rescue
      end
    end

    it 'should not log if we are not sampling' do
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA00')
      AppOpticsAPM::API.expects(:log_event).never
      result = AppOpticsAPM::SDK.trace(:test) { 42 }
      assert_equal 42, result
    end

    it "should work without request_op parameter" do
      AppOpticsAPM::API.expects(:log_entry).twice
      AppOpticsAPM::API.expects(:log_exit).twice
      AppOpticsAPM::SDK.trace(:test) do
        AppOpticsAPM::SDK.trace(:test) {}
      end
    end

    it "should respect the request_op parameter" do
      # can't stub :log_entry, because it has the logic to record with the request_op parameter
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).once
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).once

      AppOpticsAPM::SDK.trace(:test, {}, 'test') do
        AppOpticsAPM::SDK.trace(:test, {}, 'test') do
          AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        end
      end

      assert AppOpticsAPM.layer_op.empty? || AppOpticsAPM.layer_op.nil?
    end

    it "should work with sequential calls and an op paramter" do
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
      AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
      AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
    end

    it "should work with nested and sequential calls and an op param" do
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).once
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).once

      AppOpticsAPM::SDK.trace(:test, {}, 'test') do
        AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
      end
    end

    it "should create spans for different ops" do
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      AppOpticsAPM::SDK.trace(:test, {}, 'test') do
        AppOpticsAPM::SDK.trace(:test, {}, 'test_2') {}
        AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        AppOpticsAPM::SDK.trace(:test, {}, 'test_2') {}
      end
    end

    it "should create a span if the ops are not sequential" do
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, anything, anything).times(3)
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, anything, anything).times(3)

      AppOpticsAPM::SDK.trace(:test, {}, 'test') do
        AppOpticsAPM::SDK.trace(:test, {}, 'test_2') do
          AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        end
      end
    end

    it 'should do the right thing in the recursive example' do
        def computation_with_appoptics(n)
          AppOpticsAPM::SDK.trace('computation', { :number => n }, :comp) do
            return n if n == 0
            n + computation_with_appoptics(n-1)
          end
        end

        AppOpticsAPM::API.expects(:log_event).with('computation', :entry, anything, anything).once
        AppOpticsAPM::API.expects(:log_event).with('computation', :exit, anything, anything).once

        computation_with_appoptics(3)
    end
  end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  describe 'start_trace single invocation' do
    it 'should log when sampling' do
      AppOpticsAPM::API.expects(:log_start).with('test_01', nil, {})
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when sampling' do
      AppOpticsAPM::API.expects(:send_metrics).with('test_01', optionally(instance_of(Hash)))

      AppOpticsAPM::SDK.start_trace('test_01') {}
    end

    it 'should not log when NOT sampling' do
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:tracing_mode] = :disabled
      end
      AppOpticsAPM::API.expects(:log_event).never

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when NOT sampling' do
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:tracing_mode] = :disabled
      }
      AppOpticsAPM::API.expects(:send_metrics)

      AppOpticsAPM::SDK.start_trace('test_01') { 42 }
    end

    it 'should not call log or metrics methods when there is a non-sampling context' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.expects(:send_metrics).never

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should return the result from the block when there is a sampling context' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should call trace and not call log_start when there is a sampling context' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::API.expects(:send_metrics).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01', optionally(instance_of(Hash)))

      AppOpticsAPM::SDK.start_trace('test_01') { 42 }
    end

    it 'should log the tags when there is a sampling context' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')
      tags = { 'Spec' => 'rsc', 'RemoteURL' => 'https://asdf.com:1234/resource?id=5', 'IsService' => true  }

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::API.expects(:send_metrics).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01', tags)

      AppOpticsAPM::SDK.start_trace('test_01', nil, tags) { 42 }
    end

    it 'should do metrics and not logging when there is an incoming non-sampling context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00'

      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.expects(:send_metrics)

      AppOpticsAPM::SDK.start_trace('test_01', xtrace) { 42 }
    end

    it 'should send metrics when there is an incoming sampling context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01'

      AppOpticsAPM::API.expects(:send_metrics)
      sleep 0.1

      AppOpticsAPM::SDK.start_trace('test_01', xtrace) { 42 }
    end

    it 'should continue traces' do
      clear_all_traces
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01'

      result = AppOpticsAPM::SDK.start_trace('test_01', xtrace) { 42 }

      traces = get_all_traces

      assert_equal 42,              result
      assert_equal 2,               traces.size
      assert_equal 'entry',         traces[0]['Label']
      assert_equal 'exit',          traces[1]['Label']
      assert_equal xtrace[42..-3],  traces[0]['Edge']
    end

    it 'should use the transaction name from opts' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::API.expects(:log_event).with('test_01', :entry, anything, Not(has_entry(:TransactionName => 'domain/this_name')))
      AppOpticsAPM::Span.expects(:createSpan).with('this_name', nil, 0, 0).returns('domain/this_name')
      AppOpticsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'domain/this_name'))

      result = AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'this_name') { 42 }
      assert_equal 42, result
    end

    it 'should overwrite the transaction name from opts' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::API.expects(:log_event).with('test_01', :entry, anything, anything)
      AppOpticsAPM::Span.expects(:createSpan).with('custom_name_this_one', nil, 0, 0).returns('domain/custom_name_this_one')
      AppOpticsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'domain/custom_name_this_one'))
      sleep 0.1
      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsApm::SDK.set_transaction_name('custom_name_this_one')
      end
    end

    it 'should call createSpan and log_end in case of an exception' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0, 0).returns('domain/custom-test_01')
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'domain/custom-test_01'), instance_of(Oboe_metal::Event))
      begin
        AppOpticsAPM::SDK.start_trace('test_01') do
          raise StandardError
        end
      rescue StandardError
      end
    end

    it 'should report duration correctly when there is an exception' do
      AppOpticsAPM::API.expects(:log_exception).once
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 42000000, 0)
      Time.expects(:now).returns(Time.at(0))
      begin
        AppOpticsAPM::SDK.start_trace('test_01') do
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
      AppOpticsAPM::API.expects(:send_metrics).once
      sleep 0.1
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the outer layer name' do
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the opts from the first call to start_trace for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0, 0)

      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsAPM::SDK.start_trace('test_02', nil, :TransactionName => 'custom_name_02') { 42 }
      end
    end

    it 'should NOT use the opts from the second call to start_trace for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0, 0)

      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02', nil, :TransactionName => 'custom_name_02') { 42 }
      end
    end

    it 'should use the last assigned transaction name' do
      Time.expects(:now).returns(Time.at(0)).times(4)
      AppOpticsAPM::Span.expects(:createSpan).with('actually_this_one', nil, 0, 0)
      AppOpticsAPM::Span.expects(:createSpan).with('actually_this_one_as_well', nil, 0, 0)

      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsAPM::SDK.set_transaction_name('this_one')
        AppOpticsAPM::SDK.start_trace('test_02', nil, :TransactionName => 'custom_name_02') do
          AppOpticsAPM::SDK.set_transaction_name('actually_this_one')
        end
      end

      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsAPM::SDK.start_trace('test_02', nil, :TransactionName => 'custom_name_02') do
          AppOpticsAPM::SDK.set_transaction_name('this_one')
        end
        AppOpticsAPM::SDK.set_transaction_name('actually_this_one_as_well')
      end
    end

    it 'should return the result from the inner block' do
      result = AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end

      assert_equal 42, result
    end

    it 'should use the outer layer name in case of an exception' do
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))
      begin
        AppOpticsAPM::SDK.start_trace('test_01') do
          AppOpticsAPM::SDK.start_trace('test_02') do
            raise StandardError
          end
        end
      rescue StandardError
      end
    end

  end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  describe 'start_trace_with_target' do
    it 'should assign an xtrace to target' do
      target = {}
      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) {}

      assert AppOpticsAPM::XTrace.valid?(target['X-Trace'])
    end

    it 'should call trace and not call log_start when there is a sampling context' do
      target = { 'test' => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createSpan).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01', instance_of(Hash))

      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) {}
    end

    it 'should call trace and not call log_start when there is a non-sampling context' do
      target = { :test => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createSpan).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01', instance_of(Hash))

      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) { 42 }
    end

    it 'should return the result from the block when there is a non-sampling context ttt' do
      target = { :test => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      result = AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) { 42 }
      assert_equal 42, result
    end
  end

  describe 'TraceMethod' do
    before do
      clear_all_traces
    end

    after do
      clear_all_traces
      AppOpticsAPM::Context.clear
    end

    it 'traces an instance method' do
      def to_be_traced(a, b)
        a + b
      end

      AppOpticsAPM::SDK.trace_method(self.class, :to_be_traced)

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
        result = to_be_traced(3, 5)
        _(result).must_equal 8
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'to_be_traced'
      _(traces[1]['Class']).must_equal 'AppOpticsAPM::SDK::TraceMethod'
      _(traces[1]['MethodName']).must_equal 'to_be_traced'

    end

    it 'traces an instance method with a block' do
      def to_be_traced_with_block(a, b, &block)
        c = block.call
        a + b + c
      end

      AppOpticsAPM::SDK.trace_method(self.class, :to_be_traced_with_block)

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
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

      AppOpticsAPM::SDK.trace_method(self.class, :to_be_traced_2, { name: 'i_am_traced', backtrace: true })

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
        to_be_traced_2
      end

      traces = get_all_traces
      _(traces.size).must_equal 4

      _(traces[1]['Label']).must_equal 'entry'
      _(traces[1]['Layer']).must_equal 'i_am_traced'
      _(traces[1]['Class']).must_equal 'AppOpticsAPM::SDK::TraceMethod'
      _(traces[1]['MethodName']).must_equal 'to_be_traced_2'
      _(traces[2]['Backtrace']).wont_be_nil
    end

    it 'warns if we try to instrument an instance method twice' do
      AppOpticsAPM.logger.expects(:warn).with(regexp_matches(/already instrumented/))

      def to_be_traced_3
        1 + 1
      end

      AppOpticsAPM::SDK.trace_method(self.class, :to_be_traced_3)
      AppOpticsAPM::SDK.trace_method(self.class, :to_be_traced_3)
    end

    it 'traces a class method' do
      module ::TopTest
        def self.to_be_traced_4(a, b)
          a + b
        end
      end

      AppOpticsAPM::SDK.trace_method(::TopTest, :to_be_traced_4)

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
        result = ::TopTest.to_be_traced_4(5,7)
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

      AppOpticsAPM::SDK.trace_method(::TopTest, :to_be_traced_with_block_2)

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
        result = ::TopTest.to_be_traced_with_block_2(5,7) { 12 }
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

      AppOpticsAPM::SDK.trace_method(::TopTest, :to_be_traced_5, { name: 'i_am_traced', backtrace: true })

      AppOpticsAPM::SDK.start_trace('trace_test_01')  do
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
      AppOpticsAPM.logger.expects(:warn).with(regexp_matches(/already instrumented/))

      module ::TopTest
        def self.to_be_traced_6
          1 + 1
        end
      end

      AppOpticsAPM::SDK.trace_method(::TopTest, :to_be_traced_6)
      AppOpticsAPM::SDK.trace_method(::TopTest, :to_be_traced_6)
    end

  end

  describe 'log events' do
    before do
      clear_all_traces
    end

    after do
      clear_all_traces
      AppOpticsAPM::Context.clear
    end

    it 'SDK should log exceptions' do
      AppOpticsAPM::SDK.start_trace('test_01')  do
        AppOpticsAPM::SDK.log_exception( StandardError.new, { the: 'exception' })
      end

      traces = get_all_traces
      _(traces.size).must_equal 3

      _(traces[1]['Label']).must_equal 'error'
      _(traces[1]['the']).must_equal 'exception'
    end

    it 'SDK should log info' do
      AppOpticsAPM::SDK.start_trace('test_01')  do
        AppOpticsAPM::SDK.log_info( { the: 'information' })
      end

      traces = get_all_traces
      _(traces.size).must_equal 3

      _(traces[1]['Label']).must_equal 'info'
      _(traces[1]['the']).must_equal 'information'
    end
  end

  describe 'set_transaction_name' do

    it 'should not set the transaction name if the arg is not a string or an empty string' do
      AppOpticsAPM.transaction_name = nil

      AppOpticsAPM::SDK.set_transaction_name(123)
      assert_nil AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name('')
      assert_nil AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name(String.new)
      assert_nil AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name(false)
      assert_nil AppOpticsAPM.transaction_name
    end

    it 'should return the previous name, if a non-valid one is given' do
      AppOpticsAPM::SDK.set_transaction_name("this is the one")

      AppOpticsAPM::SDK.set_transaction_name(123)
      assert_equal "this is the one", AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name('')
      assert_equal "this is the one", AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name(String.new)
      assert_equal "this is the one", AppOpticsAPM.transaction_name

      AppOpticsAPM::SDK.set_transaction_name(false)
      assert_equal "this is the one", AppOpticsAPM.transaction_name

      AppOpticsAPM.transaction_name = nil
    end
  end

  describe 'tracing?' do
    it 'should return false if we are not tracing' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')
      refute AppOpticsAPM::SDK.tracing?
    end

    it 'should return true if we are tracing' do
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')
      assert AppOpticsAPM::SDK.tracing?
    end

    it 'should return false if the context is invalid' do
      AppOpticsAPM::Context.fromString('2BB05F01')
      sleep 0.1
      refute AppOpticsAPM::SDK.tracing?
    end
  end

  describe 'appoptics_ready?' do
    it 'should return true if it can connect' do
      AppOpticsAPM::Context.expects(:isReady).with(10_000).returns(1)
      assert AppOpticsAPM::SDK.appoptics_ready?(10_000)
    end

    it 'should work with no arg' do
      AppOpticsAPM::Context.expects(:isReady).returns(1)
      assert AppOpticsAPM::SDK.appoptics_ready?
    end

    it 'should return false if it cannot connect' do
      AppOpticsAPM::Context.expects(:isReady).returns(2)
      refute AppOpticsAPM::SDK.appoptics_ready?
    end
  end

  describe 'createSpan' do
    # Let's test the return value of createSpan a bit too
    it 'should return a transaction name' do
      assert_equal 'my_name', AppOpticsAPM::Span.createSpan('my_name', nil, 0, 0)
      assert_equal 'unknown', AppOpticsAPM::Span.createSpan(nil, nil, 0, 0)
      assert_equal 'unknown', AppOpticsAPM::Span.createSpan('', nil, 0, 0)
      assert_equal 'domain/my_name', AppOpticsAPM::Span.createSpan('my_name', 'domain', 0, 0)
    end
  end
end
