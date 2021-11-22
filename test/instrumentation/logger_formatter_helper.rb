# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

describe "include traceId in message " do

  before do
    AppOpticsAPM::Context.clear
    @log_traceId = AppOpticsAPM::Config[:log_traceId]

    @trace_00 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
    @trace_01 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
    @trace_id = '7435a9fe510ae4533414d425dadf4e18'
  end

  after do
    AppOpticsAPM::Context.clear
    AppOpticsAPM::Config[:log_traceId] = @log_traceId
  end

  describe "Formatted msg is a String " do
    # msg generated via :let in calling test file
    # - logger_formatter_test.rb
    # - rails_logger_formatter_test.rb
    it 'adds a traceId when :always' do
      AppOpticsAPM::Config[:log_traceId] = :always

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}00000000000000000000000000000000-0/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'adds a traceId when :traced' do
      AppOpticsAPM::Config[:log_traceId] = :traced
      AppOpticsAPM::Context.fromString(@trace_00)

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}#{@trace_id}-0/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'Does NOT add a traceId when :traced and no context' do
      AppOpticsAPM::Config[:log_traceId] = :traced

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'adds a traceId when :sampled' do
      AppOpticsAPM::Config[:log_traceId] = :sampled
      AppOpticsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}#{@trace_id}-1/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'Does NOT add a traceId when :sampled and not sampled' do
      AppOpticsAPM::Config[:log_traceId] = :sampled
      AppOpticsAPM::Context.fromString(@trace_00)

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'Does NOT add a traceId when :never' do
      AppOpticsAPM::Config[:log_traceId] = :never
      AppOpticsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'Does NOT add a traceId when no config' do
      AppOpticsAPM::Config[:log_traceId] = nil
      AppOpticsAPM::Context.fromString(@trace_01)

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

  end

  describe "Formatted msg is NOT a String" do
    # exc_message generated via :let in calling test file
    # - logger_formatter_test.rb
    # - rails_logger_formatter_test.rb
    it 'adds a ao.traceId when it is an Exception' do
      AppOpticsAPM::Config[:log_traceId] = :always

      _(exc_message).must_match /StandardError/
      _(exc_message).must_match /ao.traceId=00000000000000000000000000000000-0/
      _(exc_message).wont_match /traceId.*traceId/
    end
  end
end
