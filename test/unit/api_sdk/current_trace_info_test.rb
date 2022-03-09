# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe AppOpticsAPM::SDK do

  describe 'current_trace_info' do
    before do
      AppOpticsAPM::Context.clear

      @log_traceId = AppOpticsAPM::Config[:log_traceId]
      AppOpticsAPM::Config[:log_traceId] = :traced

      @trace_id = '7435a9fe510ae4533414d425dadf4e18'
      @span_id = '49e60702469db05f'
    end

    after do
      AppOpticsAPM.loaded = true
      AppOpticsAPM::Config[:log_traceId] = @log_traceId
      AppOpticsAPM::Context.clear
    end

    describe 'trace_id, span_id, trace_flags' do
      it 'returns an trace_id when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal @trace_id, trace.trace_id
        assert_equal @span_id, trace.span_id
        assert_equal trace_flags, trace.trace_flags
      end

      it 'returns 0s when there is no context' do
        AppOpticsAPM::Context.clear

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '00000000000000000000000000000000', trace.trace_id
        assert_equal '0000000000000000', trace.span_id
        assert_equal '00', trace.trace_flags
      end

      it 'returns 0s when Appoptics is not loaded' do
        AppOpticsAPM.loaded = false

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '00000000000000000000000000000000', trace.trace_id
        assert_equal '0000000000000000', trace.span_id
        assert_equal '00', trace.trace_flags
      end
    end

    describe 'do_log' do
      it 'never' do
        AppOpticsAPM::Config[:log_traceId] = :never

        trace = AppOpticsAPM::SDK.current_trace_info
        refute trace.do_log

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'always' do
        AppOpticsAPM::Config[:log_traceId] = :always

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'traced and valid tracestring' do
        AppOpticsAPM::Config[:log_traceId] = :traced

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace.do_log

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'traced and not valid tracestring' do
        AppOpticsAPM::Config[:log_traceId] = :traced

        trace = AppOpticsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'sampled and sampled tracestring' do
        AppOpticsAPM::Config[:log_traceId] = :sampled

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'sampled and not sampled tracestring' do
        AppOpticsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'sampled and not valid tracestring' do
        AppOpticsAPM::Config[:log_traceId] = :sampled

        trace = AppOpticsAPM::SDK.current_trace_info
        refute trace.do_log
      end
    end

    describe 'for_log' do
      it 'returns log info when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        for_log = "trace_id=#{@trace_id} span_id=#{@span_id} trace_flags=#{trace_flags}"

        trace = AppOpticsAPM::SDK.current_trace_info
        assert_equal for_log, trace.for_log
      end

      it 'returns an empty string when there is no context' do
        AppOpticsAPM::Context.clear
        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '', trace.for_log
      end

      it 'returns an empty string when do_log is false' do
        AppOpticsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '', trace.for_log
      end
    end

    describe 'hash_for_log' do
      it 'returns log info when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        for_log = { trace_id: @trace_id, span_id: @span_id, trace_flags: trace_flags }

        trace = AppOpticsAPM::SDK.current_trace_info
        assert_equal for_log, trace.hash_for_log
      end

      it 'returns an empty hash when there is no context' do
        AppOpticsAPM::Context.clear
        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal({}, trace.hash_for_log)
      end

      it 'returns an empty hash when do_log is false' do
        AppOpticsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        AppOpticsAPM::Context.fromString(tracestring)

        trace = AppOpticsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal({}, trace.hash_for_log)
      end
    end

    describe 'for_sql' do
      before do
        @sanitize = AppOpticsAPM::Config[:sanitize_sql]
        @tag_sql = AppOpticsAPM::Config[:tag_sql]

        AppOpticsAPM::Config[:sanitize_sql] = false
        AppOpticsAPM::Config[:tag_sql] = true

        @trace_id = rand(10 ** 32).to_s.rjust(32,'0')
        @span_id = rand(10 ** 16).to_s.rjust(16,'0')
        @tracestring_01 = "00-#{@trace_id}-#{@span_id}-01"
        @tracestring_00 = "00-#{@trace_id}-#{@span_id}-00"

        @sql =  "SELECT `users`.* FROM `users` WHERE (mobile IN ('234 234 234') AND email IN ('a_b_c@hotmail.co.uk'))"
      end

      after do
        AppOpticsAPM::Config[:sanitize_sql] = @sanitize
        AppOpticsAPM::Config[:tag_sql] = @tag_sql
      end

      it 'adds the trace id when tag_sql is true' do
        AppOpticsAPM::Context.fromString(@tracestring_01)
        result = AppOpticsAPM::SDK.current_trace_info.for_sql
        assert_equal "/*traceparent='#{@tracestring_01}'*/", result

        AppOpticsAPM::Context.clear
        result = AppOpticsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end

      # when log_traceId is :never (sql is not modified)
      it 'does not add the trace id when tag_sql is false' do
        AppOpticsAPM::Config[:tag_sql] = false

        AppOpticsAPM::Context.fromString(@tracestring_01)
        result = AppOpticsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end

      # when log_traceId is :traced (2 cases: none, valid)
      it 'does not add unsampled trace id' do

        AppOpticsAPM::Context.fromString(@tracestring_00)
        result = AppOpticsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end
    end
  end
end
