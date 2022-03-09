# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'TraceStringTest' do

  before do
    @trace_id = rand(10 ** 32).to_s.rjust(32,'0')
    @span_id = rand(10 ** 16).to_s.rjust(16,'0')
    @version = "00"

    @valid_tracestring =     "#{@version}-#{@trace_id}-#{@span_id}-00"
    @sampled_tracestring =   "#{@version}-#{@trace_id}-#{@span_id}-01"
    @broken_tracestring =    "#{@version}-f198ee56343ba864fe8b2a57d3eff7-#{@span_id}-01"
    @malicious_tracestring = "/*TRUNCATE TABLE users*/"
  end

  it "splits a tracestring" do
    assert AppOpticsAPM::TraceString.split(@valid_tracestring)
    assert AppOpticsAPM::TraceString.split(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.split(@broken_tracestring)
    refute AppOpticsAPM::TraceString.split(@malicious_tracestring)
  end

  it "validates a tracestring" do
    assert AppOpticsAPM::TraceString.valid?(@valid_tracestring)
    assert AppOpticsAPM::TraceString.valid?(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.valid?(@broken_tracestring)
    refute AppOpticsAPM::TraceString.valid?(@malicious_tracestring)
  end

  it "checks if a tracestring is sampled" do
    refute AppOpticsAPM::TraceString.sampled?(@valid_tracestring)
    assert AppOpticsAPM::TraceString.sampled?(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.sampled?(@broken_tracestring)
    refute AppOpticsAPM::TraceString.sampled?(@malicious_tracestring)
  end

  it "extracts the trace_id" do
    assert_equal @trace_id, AppOpticsAPM::TraceString.trace_id(@valid_tracestring)
    assert_equal @trace_id, AppOpticsAPM::TraceString.trace_id(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.trace_id(@broken_tracestring)
    refute AppOpticsAPM::TraceString.trace_id(@malicious_tracestring)
  end

  it "extracts the span_id" do
    assert_equal @span_id, AppOpticsAPM::TraceString.span_id(@valid_tracestring)
    assert_equal @span_id, AppOpticsAPM::TraceString.span_id(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.span_id(@broken_tracestring)
    refute AppOpticsAPM::TraceString.span_id(@malicious_tracestring)
    # AppOpticsAPM::TraceString.span_id
  end

  it "extracts the span_id_flags" do
    assert_equal "#{@span_id}-00", AppOpticsAPM::TraceString.span_id_flags(@valid_tracestring)
    assert_equal "#{@span_id}-01", AppOpticsAPM::TraceString.span_id_flags(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.span_id_flags(@broken_tracestring)
    refute AppOpticsAPM::TraceString.span_id_flags(@malicious_tracestring)
  end

  it "changes the tracestate to sampled" do
    sampled = @sampled_tracestring
    assert_equal sampled, AppOpticsAPM::TraceString.set_sampled(@valid_tracestring)
    assert_equal sampled, AppOpticsAPM::TraceString.set_sampled(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.set_sampled(@broken_tracestring)
    refute AppOpticsAPM::TraceString.set_sampled(@malicious_tracestring)
  end

  it "changes the tracestate to unsampled" do
    valid = @valid_tracestring
    assert_equal valid, AppOpticsAPM::TraceString.unset_sampled(@valid_tracestring)
    assert_equal valid, AppOpticsAPM::TraceString.unset_sampled(@sampled_tracestring)
    refute AppOpticsAPM::TraceString.unset_sampled(@broken_tracestring)
    refute AppOpticsAPM::TraceString.unset_sampled(@malicious_tracestring)
  end

  it "replaces the span_id_flag" do
    span_id = rand(10 ** 16).to_s.rjust(16,'0')
    span_id_flags = "#{span_id}-00"
    new_valid = "#{@version}-#{@trace_id}-#{span_id_flags}"

    assert_equal new_valid, AppOpticsAPM::TraceString.replace_span_id_flags(@valid_tracestring, span_id_flags)
    assert_equal new_valid, AppOpticsAPM::TraceString.replace_span_id_flags(@sampled_tracestring, span_id_flags)
    refute AppOpticsAPM::TraceString.replace_span_id_flags(@broken_tracestring, span_id_flags)
    refute AppOpticsAPM::TraceString.replace_span_id_flags(@malicious_tracestring, span_id_flags)
  end
end