# Copyright (c) SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Trace Context' do

  describe 'initialize' do

    it "creates a trace_context from valid traceparent and tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,sw=123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })
      assert_equal parent, context.traceparent
      assert_equal state, context.tracestate

      assert_equal '123468dadadadada-01', context.sw_member_value
      assert_equal '00-a462ade6cfe479081764cc476aa98335-123468dadadadada-01', context.tracestring
    end

    it "does not have an context if traceparent is invalid" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-'
      state = 'aa=1,sw=123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      refute context.traceparent
      refute context.tracestate
      refute context.sw_member_value
    end

    it "tracestring and traceparent are the same when tracestate is invalid" do
      parent_00 = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-00'
      state = '123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent_00,
                                                 tracestate: state })
      assert context.tracestate
      assert_equal context.traceparent, context.tracestring
      refute context.sw_member_value
    end

    it "has an sw_member_value if tracestate is a valid sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'sw=123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal '123468dadadadada-01', context.sw_member_value
    end

    it "has an sw_member_value if tracestate contains a valid sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , sw=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal '123468dadadadada-01', context.sw_member_value
    end

    it "does not have an sw_member_value if sw is not a member" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , bb=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal parent, context.traceparent
      assert_equal '%%%,aa= we:::we , bb=123468dadadadada-01, %%%', context.tracestate
      refute context.sw_member_value
    end

    it " does not have an sw_member_value if sw is not a valid member" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw==123,bb=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal parent, context.traceparent
      assert_equal ',,%%%,aa= we:::we , sw==123,bb=123468dadadadada-01, %%%', context.tracestate
      refute context.sw_member_value
      assert_equal context.traceparent, context.tracestring
    end

    it "sets the tracestring to not-sampled if the sw tracestate is not sampled" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = '%%%,aa= we:::we , sw=123468dadadadada-00, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal '00-a462ade6cfe479081764cc476aa98335-123468dadadadada-00',
                   context.tracestring
    end

    it "extracts sw_member_value if sw is in tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,sw=123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      assert_equal '123468dadadadada-01', context.sw_member_value
    end

    it "does not extract sw_member_value if sw is not in tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = 'aa=1,bb=123468dadadadada-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })

      refute context.sw_member_value
    end

  end

  describe 'add_kvs' do

    it "adds tracestate if there is a tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw==123,bb=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })
      kvs = context.add_kvs

      assert_equal state, kvs['sw.w3c.tracestate']
    end

    it "does not add tracestate if there is no tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent })
      kvs = context.add_kvs

      refute kvs['sw.w3c.tracestate']
    end

    it "adds sw.tracestate_parent_id if there is an sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , sw=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })
      kvs = context.add_kvs

      assert_equal '123468dadadadada', kvs['sw.tracestate_parent_id']
    end

    it "does not add sw.tracestate_parent_id if there is no sw tracestate" do
      parent = '00-a462ade6cfe479081764cc476aa98335-cb3468da6f06eefc-01'
      state = ',,%%%,aa= we:::we , bb=123468dadadadada-01, %%%'

      context = AppOpticsAPM::TraceContext.new({ traceparent: parent,
                                                 tracestate: state })
      kvs = context.add_kvs

      refute kvs['sw.tracestate_parent_id']
    end

  end
end
