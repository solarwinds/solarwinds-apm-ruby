#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK
    ##
    # Provides the higher-level tracing interface for the API.
    #
    # Custom Traces are best created with an <tt>AppOpticsAPM::SDK.start_trace</tt> block and
    # <tt>AppOpticsAPM::SDK.trace</tt> blocks around calls to be traced.
    # These two methods guarantee proper nesting of tracing and handling of the tracing context as well as avoiding
    # broken traces in case of exceptions
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
      # * +:span+       - The span the block of code belongs to.
      # * +:opts+       - (optional) A hash containing key/value pairs that will be reported along
      #                   with the first event of this span.
      # * +:protect_op+ - (optional) The operation being traced.  Used to avoid double tracing
      #                   operations that call each other.
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
      def trace(span, opts = {}, protect_op = nil)
        return yield if !AppOpticsAPM.loaded || !AppOpticsAPM.tracing? || (protect_op && AppOpticsAPM.layer_op == protect_op.to_sym)

        log_entry(span, opts, protect_op)
        begin
          yield
        rescue Exception => e
          log_exception(span, e)
          raise
        ensure
          log_exit(span, opts, protect_op)
          AppOpticsAPM.layer_op = nil
        end
      end

      # Public: Trace and assign the exit xtrace to `target['X-Trace']` before yielding
      # see: start_trace_with_target
      #
      # Not sure about a use case for this.
      #
      # Returns the result of the block
      def trace_with_target(span, target, opts = {}, protect_op = nil)
        return yield if !AppOpticsAPM.loaded || !AppOpticsAPM.tracing? || (protect_op && AppOpticsAPM.layer_op == protect_op.to_sym)

        log_entry(span, opts, protect_op)
        exit_evt = AppOpticsAPM::Context.createEvent

        begin
          target['X-Trace'] = AppOpticsAPM::EventUtil.metadataString(exit_evt)
          result = yield
        rescue Exception => e
          log_exception(span, e)
          exit_evt.addEdge(AppOpticsAPM::Context.get)
          xtrace = log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name || "custom-#{span}" }, exit_evt)
          AppOpticsAPM.layer_op = nil
          e.instance_variable_set(:@xtrace, xtrace)
          raise
        end

        exit_evt.addEdge(AppOpticsAPM::Context.get)
        log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name }, exit_evt)
        AppOpticsAPM.layer_op = nil

        result
      end

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
      # Returns the result of the block.
      def start_trace(span, xtrace = nil, opts = {})
        return yield unless AppOpticsAPM.loaded
        return trace(span, opts) { yield } if AppOpticsAPM::Context.isValid # not an entry span!

        log_start(span, xtrace, opts)

        # send_metrics deals with the logic for setting AppOpticsAPM.transaction_name
        # and ensures that metrics are sent
        result = send_metrics(span, opts) do
          begin
            yield
          rescue Exception => e # rescue everything ok, since we are raising
            log_exception(span, e)
            e.instance_variable_set(:@xtrace, log_end(span, :TransactionName => AppOpticsAPM.transaction_name || "custom-#{span}"))
            raise
          end
        end
        log_end(span, :TransactionName => AppOpticsAPM.transaction_name)

        result
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
      # * +span+   - The span the block of code belongs to.
      # * +xtrace+ - string - The X-Trace to continue by the target
      # * +target+ - has to respond to #[]=, The target object in which to place the trace information
      # * +opts+   - A hash containing key/value pairs that will be reported along
      #              with the first event of this span (optional).
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
      def start_trace_with_target(span, xtrace, target, opts = {})
        return yield unless AppOpticsAPM.loaded

        return trace_with_target(span, target, opts) { yield } if AppOpticsAPM::Context.isValid # not an entry span!

        log_start(span, xtrace, opts)
        exit_evt = AppOpticsAPM::Context.createEvent
        result = send_metrics(span, opts) do
          begin
            target['X-Trace'] = AppOpticsAPM::EventUtil.metadataString(exit_evt) if AppOpticsAPM.tracing?
            yield
          rescue Exception => e
            log_exception(span, e)
            exit_evt.addEdge(AppOpticsAPM::Context.get)
            xtrace = log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name || "custom-#{span}" }, exit_evt)
            e.instance_variable_set(:@xtrace, xtrace)
            AppOpticsAPM::Context.clear
            raise
          end
        end
        exit_evt.addEdge(AppOpticsAPM::Context.get)
        log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name }, exit_evt)
        AppOpticsAPM::Context.clear

        result
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

      private

      def send_metrics(span, kvs)
        # This is a new span, we do not know the transaction name yet
        AppOpticsAPM.transaction_name = nil

        # if a transaction name is provided it will take precedence over transaction names defined
        # later or in lower spans
        transaction_name = set_transaction_name(kvs[:TransactionName])
        start = Time.now

        yield
      ensure
        duration =(1000 * 1000 * (Time.now - start)).round(0)
        transaction_name ||= AppOpticsAPM.transaction_name || "custom-#{span}"
        set_transaction_name(AppOpticsAPM::Span.createSpan(transaction_name, nil, duration))
      end
    end
  end
end
