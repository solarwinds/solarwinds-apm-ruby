require 'minitest_helper'

describe AppOpticsAPM::SDK do

  describe 'current_trace' do
    after do
      AppOpticsAPM.loaded=true
      AppOpticsAPM::Context.clear
    end

    it 'returns an id when there is a context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00'
      id = '7435A9FE510AE4533414D425DADF4E180D2B4E36-0'
      AppOpticsAPM::Context.fromString(xtrace)

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal id, trace.id
    end

    it 'returns 0s when there is no context' do
      AppOpticsAPM::Context.clear

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '0000000000000000000000000000000000000000-0', trace.id
    end

    it 'returns 0s when Appoptics is not loaded' do
      AppOpticsAPM.loaded=false

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '0000000000000000000000000000000000000000-0', trace.id
    end

    it 'returns a for_log when there is a context' do
      xtrace = '2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01'
      for_log = 'traceId=7435A9FE510AE4533414D425DADF4E180D2B4E36-1'
      AppOpticsAPM::Context.fromString(xtrace)

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
      AppOpticsAPM.loaded=false

      trace = AppOpticsAPM::SDK.current_trace
      assert trace, 'it should return a trace'
      assert_equal '', trace.for_log
    end
  end
end