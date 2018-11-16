#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module API
    ##
    # Provides the higher-level tracing interface for the API
    #
    # The tracing methods have been moved to AppOpticsAPM::SDK and AppOpticsAPM::API extends all methods from the SDK
    # except for start_trace.
    # AppOpticsAPM::API.start_trace is kept for backwards compatibility because it returns an array
    # whereas AppOpticsAPM::SDK.start_trace will only return the result of the block.
    #

    module Tracing

      # Public: Collect metrics and start tracing a given block of code. A
      # trace will be started depending on configuration and probability.
      # Detect any exceptions thrown by the block and report errors.
      #
      # When start_trace returns control to the calling context, the trace will be
      # completed and the tracing context will be cleared.
      #
      # ==== Arguments
      #
      # * +span+   - name for the span to be used as label in the trace view
      # * +xtrace+ - (optional) incoming X-Trace identifier to be continued
      # * +opts+   - (optional) hash containing key/value pairs that will be reported along
      #              with the first event of this span
      #
      # ==== Example
      #
      #   def handle_request(request, response)
      #     # ... code that modifies request and response ...
      #   end
      #
      #   def handle_request_with_appoptics(request, response)
      #     start_trace('custom_span', nil, :TransactionName => 'handle_request') do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # Returns an array with the result of the block and the last xtrace used
      def start_trace(span, xtrace = nil, opts = {})
        target = {}
        [start_trace_with_target(span, xtrace, target, opts) { yield }, target['X-Trace']]
      end

    end
  end
end