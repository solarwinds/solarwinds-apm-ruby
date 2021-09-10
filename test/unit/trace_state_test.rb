# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "TraceStateTest" do
  it "adds our member" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136DFAEBDF742362')

    assert_equal("sw=136DFAEBDF742362,aa=123,bb=234,cc=567", trace_state2)
  end

  it "adds our member when there are spaces in tracestate" do
    trace_state = "aa=123, bb=234,  cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136DFAEBDF742362')

    assert_equal("sw=136DFAEBDF742362,aa=123,bb=234,cc=567", trace_state2)
  end

  it "adds our member when there are tabs in tracestate" do
    trace_state = "aa=123,\tbb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136DFAEBDF742362')

    assert_equal("sw=136DFAEBDF742362,aa=123,bb=234,cc=567", trace_state2)
  end


  it "replaces our member " do
    trace_state = "aa=123, sw=9999, bb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136DFAEBDF742362')

    assert_equal("sw=136DFAEBDF742362,aa=123,bb=234,cc=567", trace_state2)
  end

  it "discards an invalid tracestate" do
    trace_state = "aa=123,bb=234,cc=567,bogusstuff"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136DFAEBDF742362')

    assert_equal("sw=136DFAEBDF742362", trace_state2)
  end

  it "does not accept an empty parent_id" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '')

    assert_equal("aa=123,bb=234,cc=567", trace_state2)

  end

  it "does not accept a malformed parent_id" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_parent_id(trace_state, '136Dxx_742362')

    assert_equal("aa=123,bb=234,cc=567", trace_state2)
  end

end

