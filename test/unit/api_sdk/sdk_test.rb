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
    AppOpticsAPM::Config[:tracing_mode] = 'always'
    AppOpticsAPM::Config[:sample_rate] = 1000000
    clear_all_traces
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

    it "should work without request_op parameter" do
      AppOpticsAPM::API.expects(:log_entry).twice
      AppOpticsAPM::API.expects(:log_exit).twice
      AppOpticsAPM::SDK.trace(:test) do
        AppOpticsAPM::SDK.trace(:test) {}
      end
    end

    it "should respect the request_op parameter" do
      # can't stub :log_entry, because it has the logic to record with the request_op parameter
      AppOpticsAPM::API.expects(:log_event).with(:test, :entry, optionally(anything), optionally(anything)).once
      AppOpticsAPM::API.expects(:log_event).with(:test, :exit, optionally(anything), optionally(anything)).once

      AppOpticsAPM::SDK.trace(:test, {}, 'test') do
        AppOpticsAPM::SDK.trace(:test, {}, 'test') do
          AppOpticsAPM::SDK.trace(:test, {}, 'test') {}
        end
      end

      refute AppOpticsAPM.layer_op
    end

    it 'should log an entry, excepetion, and exit there is an exception' do
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
      AppOpticsAPM::API.expects(:log).never
      result = AppOpticsAPM::SDK.trace(:test) { 42 }
      assert_equal 42, result
    end
  end

  describe 'start_trace single invocation' do
    it 'should log when sampling' do
      AppOpticsAPM::API.expects(:log_start).with('test_01', nil, {})
      AppOpticsAPM::API.expects(:log_end).with('test_01')

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when sampling' do
      AppOpticsAPM::API.expects(:send_metrics).with('test_01', optionally(instance_of(Hash)))

      AppOpticsAPM::SDK.start_trace('test_01') {}
    end

    it 'should not log when NOT sampling' do
      AppOpticsAPM.config_lock.synchronize do
        AppOpticsAPM::Config[:tracing_mode] = 'never'
      end
      AppOpticsAPM::API.expects(:log_event).never

      result = AppOpticsAPM::SDK.start_trace('test_01') { 42 }
      assert_equal 42, result
    end

    it 'should send metrics when NOT sampling' do
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:tracing_mode] = 'never'
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

    it 'should do metrics and not logging when there is an incoming non-sampling context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00'

      AppOpticsAPM::API.expects(:log_event).never
      AppOpticsAPM::API.expects(:send_metrics)

      AppOpticsAPM::SDK.start_trace('test_01', xtrace) { 42 }
    end

    it 'should send metrics when there is an incoming sampling context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01'

      AppOpticsAPM::API.expects(:send_metrics)

      AppOpticsAPM::SDK.start_trace('test_01', xtrace) { 42 }
    end

    it 'should continue traces' do
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
      AppOpticsAPM::API.expects(:log_event)
      AppOpticsAPM::Span.expects(:createSpan).with('this_name', nil, 0)
      AppOpticsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'this_name'))

      result = AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'this_name') { 42 }
      assert_equal 42, result
    end

    it 'should not overwrite the transaction name from opts' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::API.expects(:log_event).with('test_01', :entry, anything, anything)
      AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
      AppOpticsAPM::API.expects(:log_event).with('test_01', :exit, anything, has_entry(:TransactionName => 'custom_name'))

      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsApm::SDK.set_transaction_name('custom_name_not_this_one')
      end
    end

    it 'should call createSpan and log_end with the transaction name from set_transaction_name' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
      AppOpticsAPM::API.expects(:log_end).with('test_01')
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsApm::SDK.set_transaction_name('custom_name')
      end
    end

    it 'should call createSpan in case of an exception' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0)
      begin
        AppOpticsAPM::SDK.start_trace('test_01') do
          raise StandardError
        end
      rescue StandardError
      end
    end

    it 'should call log_end in case of an exception' do
      AppOpticsAPM::API.expects(:log_exception)
      AppOpticsAPM::API.expects(:log_end).with('test_01')
      begin
        AppOpticsAPM::SDK.start_trace('test_01') do
          raise StandardError
        end
      rescue StandardError
      end
    end

    it 'should report duration correctly when there is an exception' do
      AppOpticsAPM::API.expects(:log_exception).once
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 42000000)
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
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the outer layer name' do
      AppOpticsAPM::API.expects(:log_end).with('test_01')
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the outer layer name for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0)
      AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end
    end

    it 'should use the outer opts :transactionName for transaction name' do
      Time.expects(:now).returns(Time.at(0)).twice
      AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
      AppOpticsAPM::SDK.start_trace('test_01', nil, :TransactionName => 'custom_name') do
        AppOpticsAPM::SDK.start_trace('test_02', nil, :TransactionName => 'custom_name_02') { 42 }
      end
    end

    it 'should return the result from the inner block' do
      result = AppOpticsAPM::SDK.start_trace('test_01') do
        AppOpticsAPM::SDK.start_trace('test_02') { 42 }
      end

      assert_equal 42, result
    end

    it 'should use the outer layer name in case of an exception' do
      AppOpticsAPM::API.expects(:log_end).with('test_01')
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
      assert target['X-Trace']
      assert_match /^2B[0-9A-F]*01$/, target['X-Trace']
    end

    it 'should call log_start and log' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::API.expects(:log_start).with('test_01', nil, {})
        AppOpticsAPM::API.expects(:log_end)
            .with('test_01', has_entry(:TransactionName => 'custom-test_01'), instance_of(Oboe_metal::Event))

        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) {}
      end
    end

    it 'should call createSpan' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0)
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) {}
      end
    end

    it 'should return the result' do
      result = AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
        42
      end

      assert_equal 42, result
    end

    it 'should return the result when not tracing' do
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:tracing_mode] = 'never'
      }
      result = AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
        42
      end

      assert_equal 42, result
    end

    it 'should call createSpan with the transaction name from the param' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}, :TransactionName => 'custom_name') {}
      end
    end

    it 'should call log with the transaction name from the param' do
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom_name'), instance_of(Oboe_metal::Event))
      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}, :TransactionName => 'custom_name') do
        42
      end
    end

    it 'should call createSpan with the transaction name from set_transaction_name' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
          AppOpticsApm::SDK.set_transaction_name('custom_name')
        end
      end
    end

    it 'should call log_end with the transaction name from set_transaction_name' do
      AppOpticsAPM::API.expects(:log_end).with('test_01', has_entry(:TransactionName => 'custom_name'), instance_of(Oboe_metal::Event))
      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
        AppOpticsApm::SDK.set_transaction_name('custom_name')
      end
    end

    it 'should not overwrite the transaction name from the params' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom_name', nil, 0)
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}, :TransactionName => 'custom_name') do
          AppOpticsApm::SDK.set_transaction_name('custom_name_not_this_one')
        end
      end
    end

    it 'should call createSpan in case of an exception' do
      Time.stub(:now, Time.at(0)) do
        AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 0)
        begin
          AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
            raise StandardError
          end
        rescue StandardError
        end
      end
    end

    it 'should call log_end in case of an exception' do
      AppOpticsAPM::API.expects(:log_exception)
      AppOpticsAPM::API.expects(:log_end).with('test_01', instance_of(Hash), instance_of(Oboe_metal::Event)).once

      begin
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
          raise StandardError
        end
      rescue StandardError
      end
    end

    it 'should call trace and not call log_start when there is a sampling context' do
      target = { 'test' => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createSpan).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01')

      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) {}
    end

    it 'should call trace and not call log_start when there is a non-sampling context' do
      target = { 'test' => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      AppOpticsAPM::API.expects(:log_start).never
      AppOpticsAPM::Span.expects(:createSpan).never
      AppOpticsAPM::API.expects(:log_end).never
      AppOpticsAPM::SDK.expects(:trace).with('test_01')

      AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) { 42 }
    end

    it 'should return the result from the block when there is a non-sampling context ttt' do
      target = { 'test' => true }
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

      result = AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, target) { 42 }
      assert_equal 42, result
    end

    it 'should report duration correctly when there is an exception' do
      AppOpticsAPM::API.expects(:log_exception).once
      AppOpticsAPM::Span.expects(:createSpan).with('custom-test_01', nil, 42000000)
      Time.expects(:now).returns(Time.at(0))
      begin
        AppOpticsAPM::SDK.start_trace_with_target('test_01', nil, {}) do
          Time.expects(:now).returns(Time.at(42))
          raise StandardError
        end
      rescue StandardError
      end
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
      refute AppOpticsAPM::SDK.tracing?
    end
  end

  describe 'appoptics_ready?' do
    it 'should return true if it can connect' do
      AppopticsAPM::Context.expects(:isReady).with(10_000).returns(true)
      assert AppOpticsAPM::SDK.appoptics_ready?(10_000)
    end

    it 'should work with no arg' do
      AppopticsAPM::Context.expects(:isReady).returns(true)
      assert AppOpticsAPM::SDK.appoptics_ready?
    end

    it 'should return false if it cannot connect' do
      AppopticsAPM::Context.expects(:isReady).returns(false)
      refute AppOpticsAPM::SDK.appoptics_ready?
    end
  end

  describe 'createSpan' do
    # Let's test the return value of createSpan a bit too
    it 'should return a transaction name' do
      assert_equal 'my_name', AppOpticsAPM::Span.createSpan('my_name', nil, 0)
      assert_equal 'unknown', AppOpticsAPM::Span.createSpan(nil, nil, 0)
      assert_equal 'unknown', AppOpticsAPM::Span.createSpan('', nil, 0)
      assert_equal 'domain/my_name', AppOpticsAPM::Span.createSpan('my_name', 'domain', 0)
    end
  end
end
