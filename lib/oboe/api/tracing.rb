# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module API
    module Tracing

      # Public: Trace a given block of code. Detect any exceptions thrown by
      # the block and report errors.
      #
      # layer - The layer the block of code belongs to.
      # opts - A hash containing key/value pairs that will be reported along
      #        with the first event of this layer (optional).
      #
      # Example
      #
      #   def computation(n)
      #     fib(n)
      #     raise Exception.new
      #   end
      #
      #   def computation_with_oboe(n)
      #     trace('fib', { :number => n }) do
      #       computation(n)
      #     end
      #   end
      #
      #   result = computation_with_oboe(1000)
      #
      # Returns the result of the block.
      def trace(layer, opts={}, protect_op=false)
        log_entry(layer, opts, protect_op)
        begin 
          yield
        rescue Exception => e
          log_exception(layer, e)
          raise
        ensure
          log_exit(layer, protect_op)
        end
      end
  
      # Public: Trace a given block of code which can start a trace depending
      # on configuration and probability. Detect any exceptions thrown by the
      # block and report errors.
      #
      # When start_trace returns control to the calling context, the oboe
      # context will be cleared.
      #
      # layer - The layer the block of code belongs to.
      # opts - A hash containing key/value pairs that will be reported along
      #        with the first event of this layer (optional).
      #
      # Example
      #
      #   def handle_request(request, response)
      #     # ... code that modifies request and response ...
      #   end
      #
      #   def handle_request_with_oboe(request, response)
      #     result, xtrace = start_trace('rails', request['X-Trace']) do
      #       handle_request(request, response)
      #     end
      #     result
      #   rescue Exception => e
      #     xtrace = e.xtrace
      #   ensure
      #     response['X-trace'] = xtrace
      #   end
      #
      # Returns a list of length two, the first element of which is the result
      # of the block, and the second element of which is the oboe context that
      # was set when the block completed execution.
      def start_trace(layer, xtrace, opts={})
        log_start(layer, xtrace, opts)
        begin
          result = yield
        rescue Exception => e
          log_exception(layer, e)
          e.instance_variable_set(:@xtrace, log_end(layer))
          raise
        end
        xtrace = log_end(layer)

        [result, xtrace]
      end

      # Public: Trace a given block of code which can start a trace depending
      # on configuration and probability. Detect any exceptions thrown by the
      # block and report errors. Insert the oboe metadata into the provided for
      # later user.
      # 
      # The motivating use case for this is HTTP streaming in rails3. We need
      # access to the exit event's trace id so we can set the header before any
      # work is done, and before any headers are sent back to the client.
      #
      # layer - The layer the block of code belongs to.
      # target - The target object in which to place the oboe metadata.
      # opts - A hash containing key/value pairs that will be reported along
      #        with the first event of this layer (optional).
      #
      # Example:
      #
      #   def handle_request(request, response)
      #     # ... code that does something with request and response ...
      #   end
      #
      #   def handle_request_with_oboe(request, response)
      #     start_trace_with_target('rails', request['X-Trace'], response) do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # Returns the result of the block.
      def start_trace_with_target(layer, xtrace, target, opts={})
        log_start(layer, xtrace, opts)
        exit_evt = Oboe::Context.createEvent
        begin
          target['X-Trace'] = exit_evt.metadataString() if Oboe::Config.tracing?
          yield
        rescue Exception => e
          log_exception(layer, e)
          raise
        ensure
          exit_evt.addEdge(Oboe::Context.get())
          log_event(layer, 'exit', exit_evt)
          Oboe::Context.clear
        end
      end
    end

    module TracingNoop
      def trace(layer, opts={})
        yield
      end

      def start_trace(layer, xtrace, opts={})
        [yield, xtrace]
      end

      def start_trace_with_target(layer, xtrace, target, opts={})
        yield
      end
    end
  end
end
