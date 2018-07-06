#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    ##
    # Traces are best created with an <tt>AppOpticsAPM::SDK.start_trace</tt> block and
    # <tt>AppOpticsAPM::SDK.trace</tt> blocks around calls to be traced.
    # These two methods guarantee proper nesting of tracing and handling of the tracing context as well as avoiding
    # broken traces in case of exceptions
    #

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
      # * +:opts+       - (optional) A hash containing key/value pairs that will be reported along with the first event of this span.
      # * +:protect_op+ - (optional) The operation being traced.  Used to avoid double tracing operations that call each other.
      #
      # Example
      #
      #   def computation(n)
      #     fib(n)
      #     raise Exception.new
      #   end
      #
      #   def computation_with_appoptics(n)
      #     trace('fib', { :number => n }, :fib) do
      #       computation(n)
      #     end
      #   end
      #
      #   result = computation_with_oboe(1000)
      #
      # Returns the result of the block.
      #
      def trace(span, opts = {}, protect_op = nil)
        return yield if !AppOpticsAPM.loaded || !AppOpticsAPM.tracing? || (protect_op && AppOpticsAPM.layer_op == protect_op.to_sym)

        AppOpticsAPM::API.log_entry(span, opts, protect_op)
        begin
          yield
        rescue Exception => e
          AppOpticsAPM::API.log_exception(span, e)
          raise
        ensure
          AppOpticsAPM::API.log_exit(span, opts, protect_op)
        end
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
      # * +opts+   - (optional) hash containing key/value pairs that will be reported along with the first event of this span
      #
      # ==== Example
      #
      #   def handle_request(request, response)
      #     # ... code that processes request and response ...
      #   end
      #
      #   def handle_request_with_appoptics(request, response)
      #     start_trace('custom_trace', nil, :TransactionName => 'handle_request') do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # Returns the result of the block.
      #
      def start_trace(span, xtrace = nil, opts = {})
        return yield unless AppOpticsAPM.loaded

        # in case it is not an entry span!
        return trace(span, opts) { yield } if AppOpticsAPM::Context.isValid

        AppOpticsAPM::API.log_start(span, xtrace, opts)

        # send_metrics deals with the logic for setting AppOpticsAPM.transaction_name
        # and ensures that metrics are sent
        # log_end includes sending the transaction_name
        result = AppOpticsAPM::API.send_metrics(span, opts) do
          begin
            yield
          rescue Exception => e # rescue everything ok, since we are raising
            AppOpticsAPM::API.log_exception(span, e)
            e.instance_variable_set(:@xtrace, AppOpticsAPM::API.log_end(span))
            raise
          end
        end
        AppOpticsAPM::API.log_end(span)

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
      # * +opts+   - A hash containing key/value pairs that will be reported along with the first event of this span (optional).
      #
      # ==== Example
      #
      #   def handle_request(request, response)
      #     # ... code that processes request and response ...
      #   end
      #
      #   def handle_request_with_appoptics(request, response)
      #     start_trace_with_target('rails', request['X-Trace'], response) do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # Returns the result of the block.
      #
      def start_trace_with_target(span, xtrace, target, opts = {})
        return yield unless AppOpticsAPM.loaded

        if AppOpticsAPM::Context.isValid # not an entry span!
          result = trace(span) { yield }
          target['X-Trace'] = AppOpticsAPM::Context.toString
          return result
        end

        AppOpticsAPM::API.log_start(span, xtrace, opts)
        exit_evt = AppOpticsAPM::Context.createEvent
        result = AppOpticsAPM::API.send_metrics(span, opts) do
          begin
            target['X-Trace'] = AppOpticsAPM::EventUtil.metadataString(exit_evt) if AppOpticsAPM.tracing?
            yield
          rescue Exception => e
            AppOpticsAPM::API.log_exception(span, e)
            exit_evt.addEdge(AppOpticsAPM::Context.get)
            xtrace = AppOpticsAPM::API.log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name || "custom-#{span}" }, exit_evt)
            e.instance_variable_set(:@xtrace, xtrace)
            AppOpticsAPM::Context.clear
            raise
          end
        end
        exit_evt.addEdge(AppOpticsAPM::Context.get)
        AppOpticsAPM::API.log(span, :exit, { :TransactionName => AppOpticsAPM.transaction_name }, exit_evt)
        AppOpticsAPM::Context.clear

        result
      end

      # Public: Set a ThreadLocal custom transaction name to be used when sending a trace or metrics for the
      # current transaction.
      #
      # In addition to setting a transaction name here there is also a configuration.
      # AppOpticsAPM::Config['transaction_name']['prepend_domain']. When true the domain will be prepended
      # to the transaction name.
      #
      # ===== Argument
      #
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


      # Public: Get the currently set transaction name.
      # This is provided for testing.
      #
      # Returns the current transaction name.
      def get_transaction_name
        AppOpticsAPM.transaction_name
      end

      # Public: Determine if this transaction is being traced.
      # Tracing puts some extra load on a system, therefor not all transaction are traced.
      # The `tracing?` method helps to determine this so that extra work can be avoided when not tracing.
      #
      # ==== Example
      #
      #   kvs = expensive_info_gathering_method  if AppOpticsAPM::SDK.tracing?
      #   AppOpticsAPM::SDK.trace('some_span', kvs) do
      #     # this may not create a trace every time it runs
      #     db_request
      #   end
      #
      # Returns true or false.
      #
      def tracing?
        AppOpticsAPM.tracing?
      end

      # Public: Wait for AppOptics to be ready to send traces.
      # This may be useful in short lived background processes, when it is important to capture
      # information during the whole time the process is running. Usually AppOptics doesn't block an
      # application while it is starting up.
      #
      # ==== Argument
      #
      # * +wait_milliseconds+ the maximum time to wait in milliseconds, default 3000
      #
      # ==== Example
      #
      #   unless AppopticsAPM::SDK.appoptics_ready?
      #     Logger.info "AppOptics not ready after 10 seconds, no metrics will be sent"
      #   end
      #
      # Returns true or false.
      #
      def appoptics_ready?(wait_milliseconds = 3000)
        AppopticsAPM::Context.isReady(wait_milliseconds)
      end
    end

    extend Tracing
  end
end
