# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  class TraceContext

    attr_reader :version, :trace_id, :parent_id, :sampled, :xtrace

    def initialize(traceparent, tracestate)
       @trace_id = TraceParent.extract_id(traceparent)
       if @trace_id
         @parent_id, @sampled = TraceState.extract_sw_parent_id_sampled(tracestate)
         if @sampled == true
           @xtrace = Xtrace.set_sampled(traceparent)
         elsif @sampled == false
           @xtrace = Xtrace.unset_sampled(traceparent)
         else
           @xtrace = traceparent
         end
       end
    end

  end

end