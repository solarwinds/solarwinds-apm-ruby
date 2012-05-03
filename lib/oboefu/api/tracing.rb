# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module API
    module Tracing

      # Takes a layer name and a dictionary of key/value pairs that will be
      # added to the entry event. A block must be provided, which will be
      # wrapped in calls to log_entry() and log_exit(). Exceptions will be
      # logged and reraised.
      #
      # Using trace, you can create an instrumented version of any proc or
      # lambda and replace the original transparently. For example:
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
      def trace(layer, opts={})
        log_entry(layer, opts)
        begin 
          yield
        rescue Exception => e
          log_exception(layer, e)
        ensure
          log_exit(layer)
        end
      end
  
      # Takes a layer name and a dictionary of key/value pairs that will be
      # added to the entry event. A block must be provided, which will be
      # wrapped in calls to log_start() and log_exception(). Exceptions will be
      # logged and reraised. In addition an 'xtrace' attribute will be added to
      # the exception containing the oboe context that was set after the
      # exception was logged.
      #
      # Start trace returns a list of length two, the first element of which is
      # the return type of the block, and the second element of which is the
      # oboe context that was set when the block completed execution.
      #
      # When start_trace returns control to the calling context, the oboe
      # context will be cleared.
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
      def start_trace(layer, xtrace, opts={})
        log_start(layer, xtrace, opts)
        begin
          result = yield
          xtrace = log_end(layer)
          [result, xtrace]
        rescue Exception => e
          log_exception(layer, e)
          class << e
            attr_accessor :xtrace
          end
          e.xtrace = log_end(layer)
          raise
        ensure
          log_end(layer)
        end
      end
    end
  end
end
