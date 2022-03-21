# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe SolarWindsAPM::SDK do

  describe 'current_trace_info' do
    before do
      SolarWindsAPM::Context.clear

      @log_traceId = SolarWindsAPM::Config[:log_traceId]
      SolarWindsAPM::Config[:log_traceId] = :traced

      @trace_id = '7435a9fe510ae4533414d425dadf4e18'
      @span_id = '49e60702469db05f'
    end

    after do
      SolarWindsAPM.loaded = true
      SolarWindsAPM::Config[:log_traceId] = @log_traceId
      SolarWindsAPM::Context.clear
    end

    describe 'trace_id, span_id, trace_flags' do
      it 'returns an trace_id when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal @trace_id, trace.trace_id
        assert_equal @span_id, trace.span_id
        assert_equal trace_flags, trace.trace_flags
      end

      it 'returns 0s when there is no context' do
        SolarWindsAPM::Context.clear

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '00000000000000000000000000000000', trace.trace_id
        assert_equal '0000000000000000', trace.span_id
        assert_equal '00', trace.trace_flags
      end

      it 'returns 0s when Appoptics is not loaded' do
        SolarWindsAPM.loaded = false

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '00000000000000000000000000000000', trace.trace_id
        assert_equal '0000000000000000', trace.span_id
        assert_equal '00', trace.trace_flags
      end
    end

    describe 'do_log' do
      it 'never' do
        SolarWindsAPM::Config[:log_traceId] = :never

        trace = SolarWindsAPM::SDK.current_trace_info
        refute trace.do_log

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'always' do
        SolarWindsAPM::Config[:log_traceId] = :always

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'traced and valid tracestring' do
        SolarWindsAPM::Config[:log_traceId] = :traced

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace.do_log

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'traced and not valid tracestring' do
        SolarWindsAPM::Config[:log_traceId] = :traced

        trace = SolarWindsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'sampled and sampled tracestring' do
        SolarWindsAPM::Config[:log_traceId] = :sampled

        trace_flags = '01'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace.do_log
      end

      it 'sampled and not sampled tracestring' do
        SolarWindsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        refute trace.do_log
      end

      it 'sampled and not valid tracestring' do
        SolarWindsAPM::Config[:log_traceId] = :sampled

        trace = SolarWindsAPM::SDK.current_trace_info
        refute trace.do_log
      end
    end

    describe 'for_log' do
      it 'returns log info when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        for_log = "trace_id=#{@trace_id} span_id=#{@span_id} trace_flags=#{trace_flags}"

        trace = SolarWindsAPM::SDK.current_trace_info
        assert_equal for_log, trace.for_log
      end

      it 'returns an empty string when there is no context' do
        SolarWindsAPM::Context.clear
        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '', trace.for_log
      end

      it 'returns an empty string when do_log is false' do
        SolarWindsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal '', trace.for_log
      end
    end

    describe 'hash_for_log' do
      it 'returns log info when there is a context' do
        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        for_log = { trace_id: @trace_id, span_id: @span_id, trace_flags: trace_flags }

        trace = SolarWindsAPM::SDK.current_trace_info
        assert_equal for_log, trace.hash_for_log
      end

      it 'returns an empty hash when there is no context' do
        SolarWindsAPM::Context.clear
        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal({}, trace.hash_for_log)
      end

      it 'returns an empty hash when do_log is false' do
        SolarWindsAPM::Config[:log_traceId] = :sampled

        trace_flags = '00'
        tracestring = "00-#{@trace_id}-#{@span_id}-#{trace_flags}"
        SolarWindsAPM::Context.fromString(tracestring)

        trace = SolarWindsAPM::SDK.current_trace_info
        assert trace, 'it should return a trace'
        assert_equal({}, trace.hash_for_log)
      end
    end

    describe 'for_sql' do
      before do
        @sanitize = SolarWindsAPM::Config[:sanitize_sql]
        @tag_sql = SolarWindsAPM::Config[:tag_sql]

        SolarWindsAPM::Config[:sanitize_sql] = false
        SolarWindsAPM::Config[:tag_sql] = true

        @trace_id = rand(10 ** 32).to_s.rjust(32,'0')
        @span_id = rand(10 ** 16).to_s.rjust(16,'0')
        @tracestring_01 = "00-#{@trace_id}-#{@span_id}-01"
        @tracestring_00 = "00-#{@trace_id}-#{@span_id}-00"

        @sql =  "SELECT `users`.* FROM `users` WHERE (mobile IN ('234 234 234') AND email IN ('a_b_c@hotmail.co.uk'))"
      end

      after do
        SolarWindsAPM::Config[:sanitize_sql] = @sanitize
        SolarWindsAPM::Config[:tag_sql] = @tag_sql
      end

      it 'adds the trace id when tag_sql is true' do
        SolarWindsAPM::Context.fromString(@tracestring_01)
        result = SolarWindsAPM::SDK.current_trace_info.for_sql
        assert_equal "/*traceparent='#{@tracestring_01}'*/", result

        SolarWindsAPM::Context.clear
        result = SolarWindsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end

      # when log_traceId is :never (sql is not modified)
      it 'does not add the trace id when tag_sql is false' do
        SolarWindsAPM::Config[:tag_sql] = false

        SolarWindsAPM::Context.fromString(@tracestring_01)
        result = SolarWindsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end

      # when log_traceId is :traced (2 cases: none, valid)
      it 'does not add unsampled trace id' do

        SolarWindsAPM::Context.fromString(@tracestring_00)
        result = SolarWindsAPM::SDK.current_trace_info.for_sql
        assert_equal '', result
      end
    end
  end
end
