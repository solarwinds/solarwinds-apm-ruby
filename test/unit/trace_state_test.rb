# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "TraceStateTest" do

  # TODO add dash before flags once we use the w3c trace id formatting
  it "adds our member" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "adds our member to an empty tracestate" do
    trace_state = ""
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201", trace_state2)
  end

  it "adds our member to a nil tracestate" do
    trace_state = nil
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201", trace_state2)
  end

  it "adds our member when there are spaces in tracestate" do
    trace_state = "aa=123, bb=234,  cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "omits empty members" do
    trace_state = "aa=123, bb=234,,,  cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end


  it "omits invalid members" do
    trace_state = "aa=123,0xaa=0xaa , cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,cc=567", trace_state2)
  end


  it "adds our member when there are tabs in tracestate" do
    trace_state = "aa=123,\tbb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "replaces our member" do
    trace_state = "aa=123, sw=9999, bb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "discards an invalid tracestate member" do
    trace_state = "aa=123,bb=234,cc=567,bogusstuff"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "discards keys containing whitespaces" do
    trace_state = "aa=123,bb=234, white space = 888, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "preserves leading whitespaces in values" do
    trace_state = "aa=123, bb=   234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=   234,cc=567", trace_state2)
  end

  it "supports multitenant vendor keys" do
    trace_state = "aa=123, 0mg@a-vendor=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,0mg@a-vendor=234,cc=567", trace_state2)
  end

  it "supports _-*/ in keys" do
    trace_state = "aa=123, omg/what_is-this*thing=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,omg/what_is-this*thing=234,cc=567", trace_state2)
  end

  it "accepts *-_/ in tenant" do
    trace_state = "aa=123, 0_-*/mg@a-vendor=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,0_-*/mg@a-vendor=234,cc=567", trace_state2)
  end

  it "rejects keys that are too long" do
    trace_state = "aa=123, #{'a' * 257}=9999, bb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "rejects tenant keys that are too long" do
    trace_state = "aa=123, #{'a' * 242}@aa=9999, bb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,aa=123,bb=234,cc=567", trace_state2)
  end

  it "rejects values that are too long" do
    trace_state = "aa=#{'0' * 257}, bb=234, cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,bb=234,cc=567", trace_state2)
  end

  it "will not exceed 32 members" do
    trace_state = (0..31).to_a.map { |i| "a#{i}=123" }.join(',')
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136DFAEBDF74236201')

    assert_equal("sw=136DFAEBDF74236201,a0=123,a1=123,a2=123,a3=123,a4=123,a5=123,a6=123,a7=123,a8=123,a9=123,a10=123,a11=123,a12=123,a13=123,a14=123,a15=123,a16=123,a17=123,a18=123,a19=123,a20=123,a21=123,a22=123,a23=123,a24=123,a25=123,a26=123,a27=123,a28=123,a29=123,a30=123", trace_state2)
  end

  it "does not accept an empty parent_id" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '')

    assert_equal("aa=123,bb=234,cc=567", trace_state2)
  end

  it "does not accept a malformed parent_id" do
    trace_state = "aa=123,bb=234,cc=567"
    trace_state2 = AppOpticsAPM::TraceState.add_kv(trace_state, '136Dxx_742362')

    assert_equal("aa=123,bb=234,cc=567", trace_state2)
  end

  describe 'validate_fix' do
    it "does not alter a valid trace state" do
      trace_state = "aa=123,1234@bb=234,cc=567"

      trace_state2 = AppOpticsAPM::TraceState.validate_fix(trace_state)

      assert_equal(trace_state, trace_state2)

    end

    it "removes bad members" do
      trace_state = "aa=123,1234@bb,cc=567"

      trace_state2 = AppOpticsAPM::TraceState.validate_fix(trace_state)

      assert_equal("aa=123,cc=567", trace_state2)

    end
  end
end

