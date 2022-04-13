# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

describe "include trace_id in message " do

  before do
    @log_traceId = SolarWindsAPM::Config[:log_traceId]

    @trace_00 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
    @trace_01 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
    @trace_id = '7435a9fe510ae4533414d425dadf4e18'
    @span_id = '49e60702469db05f'
  end

  after do
    SolarWindsAPM::Config[:log_traceId] = @log_traceId
    SolarWindsAPM::Context.clear
  end

  describe "Formatted msg is a String " do
    # `msg` generated via :let in calling test file
    # - logger_formatter_test.rb
    # - rails_logger_formatter_test.rb
    it 'adds trace info when :always' do
      SolarWindsAPM::Config[:log_traceId] = :always
      SolarWindsAPM::Context.clear

      _(msg).must_match /Message/
      _(msg).must_match /trace_id=00000000000000000000000000000000/
      _(msg).must_match /span_id=0000000000000000/
      _(msg).must_match /trace_flags=00/
      _(msg).wont_match /trace_id.*trace_id/, "duplicate trace info in log"
    end

    it 'adds trace info when :traced' do
      SolarWindsAPM::Config[:log_traceId] = :traced
      SolarWindsAPM::Context.fromString(@trace_00)

      _(msg).must_match /Message/
      _(msg).must_match /trace_id=#{@trace_id}/
      _(msg).must_match /span_id=#{@span_id}/
      _(msg).must_match /trace_flags=00/
      _(msg).wont_match /trace_id.*trace_id/, "duplicate trace info in log"
    end

    it 'Does NOT add trace info when :traced and no context' do
      SolarWindsAPM::Config[:log_traceId] = :traced
      SolarWindsAPM::Context.clear

      _(msg).must_match /Message/
      _(msg).wont_match /trace_id/
    end

    it 'adds trace info when :sampled' do
      SolarWindsAPM::Config[:log_traceId] = :sampled
      SolarWindsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).must_match /trace_id=#{@trace_id}/
      _(msg).must_match /span_id=#{@span_id}/
      _(msg).must_match /trace_flags=01/
      _(msg).wont_match /trace_id.*trace_id/
    end

    it 'Does NOT add trace info when :sampled and not sampled' do
      SolarWindsAPM::Config[:log_traceId] = :sampled
      SolarWindsAPM::Context.fromString(@trace_00)

      _(msg).must_match /Message/
      _(msg).wont_match /trace_id/
    end

    it 'Does NOT add trace info when :never' do
      SolarWindsAPM::Config[:log_traceId] = :never
      SolarWindsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).wont_match /trace_id/
    end

    it 'Does NOT add trace info when no config' do
      SolarWindsAPM::Config[:log_traceId] = nil
      SolarWindsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).wont_match /trace_id/
    end

  end

  describe "when there is an exception" do
    # exc_message generated via :let in calling test file
    # - logger_formatter_test.rb
    # - rails_logger_formatter_test.rb
    it 'adds 0s' do
      SolarWindsAPM::Config[:log_traceId] = :always
      SolarWindsAPM::Context.clear

      _(exc_message).must_match /StandardError/
      _(exc_message).must_match /trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00/
      _(exc_message).wont_match /trace_id.*trace_id/
    end
  end
end
