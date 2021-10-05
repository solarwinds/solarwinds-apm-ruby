# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Trace Context' do

  describe 'initialize' do

    it "creates a trace_context from valid traceparent and tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = 'aa=1,sw=CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, context.xtrace
      assert_equal state, context.tracestate
      assert_equal 'CB3468DA6F06EEFC01', context.sw_tracestate
      assert_equal 'CB3468DA6F06EEFC', context.parent_id
    end

    it "does not have an xtrace if traceparent is invalid" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC'
      state = 'aa=1,sw=CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      refute context.xtrace
      refute context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "has a sampling xtrace if tracestate is invalid" do
      parent    = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC00'
      parent_01 = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = 'CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent_01, context.xtrace
      refute context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "has an sw_tracestate if tracestate is a valid sw tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = 'sw=CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'CB3468DA6F06EEFC01', context.sw_tracestate
    end

    it "has an sw_tracestate if tracestate contains a valid sw tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = '%%%,aa= we:::we , sw=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'CB3468DA6F06EEFC01', context.sw_tracestate
    end

    it "does not have an sw_tracestate if sw is not a member" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = '%%%,aa= we:::we , bb=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, context.xtrace
      assert_equal 'aa= we:::we,bb=CB3468DA6F06EEFC01', context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it " does not have an sw_tracestate if sw is not a valid member" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = ',,%%%,aa= we:::we , sw==123,bb=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, context.xtrace
      assert_equal 'aa= we:::we,bb=CB3468DA6F06EEFC01', context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "sets the xtrace to sampled if the sw tracestate is sampled" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC00'
      state = '%%%,aa= we:::we , sw=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01', context.xtrace
    end

    it "sets the xtrace to not-sampled if the sw tracestate is not sampled" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = '%%%,aa= we:::we , sw=CB3468DA6F06EEFC00, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC00', context.xtrace

    end

    it "extracts parent_id if sw is in tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = 'aa=1,sw=CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'CB3468DA6F06EEFC', context.parent_id
    end

    it "does not extract parent_id if sw is not in tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = 'aa=1,bb=CB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      refute context.parent_id
    end

  end

  describe 'add_kvs' do

    it "adds tracestate if there is a tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = ',,%%%,aa= we:::we , sw==123,bb=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      assert_equal state, kvs['W3C_tracestate']
    end

    it "does not add tracestate if there is no tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'

      context = AppOpticsAPM::TraceContext.new(parent)
      kvs = context.add_kvs

      refute kvs['W3C_tracestate']
    end

    it "adds SWParentID if there is an sw tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = ',,%%%,aa= we:::we , sw=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      assert_equal 'CB3468DA6F06EEFC', kvs['SWParentID']
    end

    it "does not add SWParentID if there is no sw tracestate" do
      parent = '2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFC01'
      state = ',,%%%,aa= we:::we , bb=CB3468DA6F06EEFC01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      refute kvs['SWParentID']
    end

  end
end
