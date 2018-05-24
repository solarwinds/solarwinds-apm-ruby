#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module API
    ##
    # Provides the higher-level tracing interface for the API.
    #
    # Traces are best created with a <tt>AppOpticsAPM:API.start_trace</tt> block and
    # <tt>AppOpticsAPM:API.trace</tt> blocks around calls to be traced.
    # These two methods guarantee proper nesting of tracing and handling of the tracing context.
    #
    # Some optional keys that can be used in the +opts+ hash:
    # * +:TransactionName+ - this will show up in the transactions column in the traces dashboard
    # * +:Controller+ - if present will be combined with +Action+ and show up as transaction in the traces dashboard
    # * +:Action+ - if present will be combined with +Controller+ and show up as transaction in the traces dashboard
    # * +:HTTP-Host+ - domain portion of URL
    # * +:URL+ - request URI
    # * +:Method+
    #
    # TODO complete the above
    #
    # Invalid keys: +:Label+, +:Layer+, +:Edge+, +:Timestamp+, +:Timestamp_u+
    #
    module Tracing
      # Public: Trace a given block of code. Detect any exceptions thrown by
      # the block and report errors.
      #
      # * +:layer+ - The layer the block of code belongs to.
      # * +:opts+ - A hash containing key/value pairs that will be reported along
      #   with the first event of this layer (optional).
      # * +:protect_op+ - The operation being traced.  Used to avoid
      #   double tracing operations that call each other
      #
      # Example
      #
      #   def computation(n)
      #     fib(n)
      #     raise Exception.new
      #   end
      #
      #   def computation_with_oboe(n)
      #     trace('fib', { :number => n }, :fib) do
      #       computation(n)
      #     end
      #   end
      #
      #   result = computation_with_oboe(1000)
      #
      # Returns the result of the block.
      def trace(layer, opts = {}, protect_op = nil)
        return if !AppOpticsAPM.loaded || (protect_op && AppOpticsAPM.layer_op == protect_op.to_sym)

        log_entry(layer, opts, protect_op)
        begin
          yield
        rescue Exception => e
          log_exception(layer, e)
          raise
        ensure
          log_exit(layer, opts, protect_op)
        end
      end

      # Public: Trace a given block of code which can start a trace depending
      # on configuration and probability. Detect any exceptions thrown by the
      # block and report errors.
      #
      # When start_trace returns control to the calling context, the oboe
      # context will be cleared.
      #
      # ==== Arguments
      #
      # * +layer+  - name for the layer to be used as label in the trace view
      # * +xtrace+ - (optional) incoming X-Trace identifier to be continued
      # * +opts+   - (optional) hash containing key/value pairs that will be reported along
      #   with the first event of this layer (optional)
      #
      # ==== Example
      #
      #   def handle_request(request, response)
      #     # ... code that modifies request and response ...
      #   end
      #
      #   def handle_request_with_appoptics(request, response)
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
      def start_trace(layer, xtrace = nil, opts = {})
        return [yield, nil] unless AppOpticsAPM.loaded

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
      # block and report errors. Assign an X-Trace to the target.
      #
      # The motivating use case for this is HTTP streaming in rails3. We need
      # access to the exit event's trace id so we can set the header before any
      # work is done, and before any headers are sent back to the client.
      #
      # ===== Arguments
      # * +layer+ - The layer the block of code belongs to.
      # * +xtrace+ - string - The X-Trace to continue by the target
      # * +target+ - has to respond to #[]=, The target object in which to place the trace information
      # * +opts+ - A hash containing key/value pairs that will be reported along
      #   with the first event of this layer (optional).
      #
      # ==== Example
      #
      #   def handle_request(request, response)
      #     # ... code that does something with request and response ...
      #   end
      #
      #   def handle_request_with_appoptics(request, response)
      #     start_trace_with_target('rails', request['X-Trace'], response) do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # Returns the result of the block.
      def start_trace_with_target(layer, xtrace, target, opts = {})
        return yield unless AppOpticsAPM.loaded

        log_start(layer, xtrace, opts)
        exit_evt = AppOpticsAPM::Context.createEvent
        begin
          target['X-Trace'] = AppOpticsAPM::EventUtil.metadataString(exit_evt) if AppOpticsAPM.tracing?
          yield
        rescue Exception => e
          log_exception(layer, e)
          raise
        ensure
          exit_evt.addEdge(AppOpticsAPM::Context.get)
          log(layer, :exit, {}, exit_evt)
          AppOpticsAPM::Context.clear
        end
      end

      # Public: Set a ThreadLocal custom transaction name to be used when sending a trace or metrics for the
      # current transaction
      #
      # In addition to setting a transaction name here there is also a configuration
      # AppOpticsAPM::Config['transaction_name']['prepend_domain'] which allows to have the domain prepended
      # to the transaction name
      #
      # ===== Arguments
      # * +name+ - A non-empty string with the custom transaction name
      #
      def set_transaction_name(name)
        if name.is_a?(String) && name.strip != ''
          AppOpticsAPM.transaction_name = name
        else
          AppOpticsAPM.logger.debug "[appoptics_apm/api] Could not set transaction name, provided name is empty or not a String."
        end
        AppOpticsAPM.transaction_name
      end


      # this is provided for testing
      # returns the current transaction name
      def get_transaction_name
        AppOpticsAPM.transaction_name
      end
    end
  end
end
