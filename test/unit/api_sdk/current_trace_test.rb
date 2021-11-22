# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe AppOpticsAPM::SDK do

  describe 'current_trace' do
    before do
      AppOpticsAPM::Context.clear
      AppOpticsAPM::Config[:log_traceId] = :traced
    end

    after do
      AppOpticsAPM.loaded = true
      AppOpticsAPM::Context.clear
    end

    it 'returns an id when there is a context' do
      tracestring = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
      id = '7435a9fe510ae4533414d425dadf4e18-0'
      AppOpticsAPM::Context.fromString(tracestring)

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal id, trace.id
    end

    it 'returns 0s when there is no context' do
      AppOpticsAPM::Context.clear

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '00000000000000000000000000000000-0', trace.id
    end

    it 'returns 0s when Appoptics is not loaded' do
      AppOpticsAPM.loaded = false

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '00000000000000000000000000000000-0', trace.id
    end

    it 'returns a for_log when there is a context' do
      tracestring = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
      id = '7435a9fe510ae4533414d425dadf4e18-1'
      for_log = 'ao.traceId=7435a9fe510ae4533414d425dadf4e18-1'
      AppOpticsAPM::Context.fromString(tracestring)

      trace = AppOpticsAPM::SDK.current_trace
      assert_equal for_log, trace.for_log
    end

    it 'returns an empty string for for_log when there is no context' do
      AppOpticsAPM::Context.clear
      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '', trace.for_log
    end

    it 'returns an empty string for for_log when Appoptics is not loaded' do
      AppOpticsAPM.loaded = false

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '', trace.for_log
    end
  end
end
