# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Trace Context' do

  describe 'initialize' do

    it "creates a trace_context from valid traceparent and tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,sw=cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)
      assert_equal state, context.tracestate
      assert_equal 'cb3468da6f06eefc-01', context.sw_tracestate
      assert_equal 'cb3468da6f06eefc', context.parent_id
    end

    it "does not have an xtrace if traceparent is invalid" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-'
      state = 'aa=1,sw=cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      refute context.xtrace
      refute context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "has a sampling xtrace if tracestate is invalid" do
      parent    = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-00'
      parent_01 = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent_01, AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)
      refute context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "has an sw_tracestate if tracestate is a valid sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'sw=cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'cb3468da6f06eefc-01', context.sw_tracestate
    end

    it "has an sw_tracestate if tracestate contains a valid sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , sw=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'cb3468da6f06eefc-01', context.sw_tracestate
    end

    it "does not have an sw_tracestate if sw is not a member" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , bb=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)
      assert_equal 'aa= we:::we,bb=cb3468da6f06eefc-01', context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it " does not have an sw_tracestate if sw is not a valid member" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw==123,bb=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal parent, AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)
      assert_equal 'aa= we:::we,bb=cb3468da6f06eefc-01', context.tracestate
      refute context.sw_tracestate
      refute context.parent_id
    end

    it "sets the xtrace to sampled if the sw tracestate is sampled" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-00'
      state = '%%%,aa= we:::we , sw=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01',
                   AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)
    end

    it "sets the xtrace to not-sampled if the sw tracestate is not sampled" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , sw=cb3468da6f06eefc-00, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-00',
                   AppOpticsAPM::TraceContext.ao_to_w3c_trace(context.xtrace)

    end

    it "extracts parent_id if sw is in tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,sw=cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      assert_equal 'cb3468da6f06eefc', context.parent_id
    end

    it "does not extract parent_id if sw is not in tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,bb=cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent, state)

      refute context.parent_id
    end

  end

  describe 'add_kvs' do

    it "adds tracestate if there is a tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw==123,bb=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      assert_equal state, kvs['sw.w3c.tracestate']
    end

    it "does not add tracestate if there is no tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new(parent)
      kvs = context.add_kvs

      refute kvs['sw.w3c.tracestate']
    end

    it "adds sw.parent_id if there is an sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      assert_equal 'cb3468da6f06eefc', kvs['sw.parent_id']
    end

    it "does not add sw.parent_id if there is no sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , bb=cb3468da6f06eefc-01, %%%'

      context = AppOpticsAPM::TraceContext.new(parent, state)
      kvs = context.add_kvs

      refute kvs['sw.parent_id']
    end

  end
end
