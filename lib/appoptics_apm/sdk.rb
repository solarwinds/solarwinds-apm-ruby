#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    ##
    # Traces are best created with an <tt>AppOpticsAPM::SDK.start_trace</tt> block and
    # <tt>AppOpticsAPM::SDK.trace</tt> blocks around calls to be traced.
    # These two methods guarantee proper nesting of traces, handling of the tracing context, as well as avoiding
    # broken traces in case of exceptions.
    #
    # Some optional keys that can be used in the +opts+ hash:
    # * +:TransactionName+ - this will show up in the transactions column in the traces dashboard
    # * +:Controller+ - if present will be combined with +Action+ and show up as transaction in the traces dashboard
    # * +:Action+ - if present will be combined with +Controller+ and show up as transaction in the traces dashboard
    # * +:HTTP-Host+ - domain portion of URL
    # * +:URL+ - request URI
    # * +:Method+
    #
    # Invalid keys: +:Label+, +:Layer+, +:Edge+, +:Timestamp+, +:Timestamp_u+
    #
    # The methods are exposed as singleton methods for AppOpticsAPM::SDK.
    #
    # === Usage:
    # * +AppOpticsAPM::SDK.appoptics_ready?+
    # * +AppOpticsAPM::SDK.get_transaction_name+
    # * +AppOpticsAPM::SDK.set_transaction_name+
    # * +AppOpticsAPM::SDK.start_trace+
    # * +AppOpticsAPM::SDK.start_trace_sith_target+
    # * +AppOpticsAPM::SDK.trace+
    # * +AppOpticsAPM::SDK.tracing?+
    #
    # === Example:
    #   class MonthlyCouponEmailJob
    #     def perform(*args)
    #
    #       # KVs to report to the dashboard
    #       report_kvs = {}
    #       report_kvs[:Spec] = :job
    #       report_kvs[:Controller] = :MonthlyEmailJob
    #       report_kvs[:Action] = :CouponEmailer
    #
    #       # Start tracing this job with start_trace
    #       AppOpticsAPM::SDK.start_trace('starling', nil, report_kvs) do
    #         monthly = MonthlyEmail.new(:CouponEmailer)
    #
    #         # Trace a sub-component of this trace
    #         AppOpticsAPM::SDK.trace(self.class.name) do
    #
    #           # The work to be done
    #           users = User.all
    #           users.each do |u|
    #             monthly.send(u.email)
    #           end
    #
    #         end
    #       end
    #     end
    #   end
    #
    module Tracing

      # Trace a given block of code.
      #
      # Also detects any exceptions thrown by the block and report errors.
      #
      # === Arguments:
      # * +:span+       - The span the block of code belongs to.
      # * +:opts+       - (optional) A hash containing key/value pairs that will be reported along with the first event of this span.
      # * +:protect_op+ - (optional) The operation being traced.  Used to avoid double tracing operations that call each other.
      #
      # === Example:
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
      #   result = computation_with_appoptics(100)
      #
      # === Returns:
      # * The result of the block.
      #
      def trace(span, opts = {}, protect_op = nil)
        return yield if !AppOpticsAPM.loaded || !AppOpticsAPM.tracing? || (protect_op && AppOpticsAPM.layer_op == protect_op.to_sym)

        opts.delete(:TransactionName)
        opts.delete('TransactionName')

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


      # Collect metrics and start tracing a given block of code.
      #
      # This will start a trace depending on configuration and probability, detect any exceptions
      # thrown by the block, and report errors.
      #
      # When start_trace returns control to the calling context, the trace will be
      # completed and the tracing context will be cleared.
      #
      # === Arguments:
      #
      # * +span+   - Name for the span to be used as label in the trace view.
      # * +xtrace+ - (optional) incoming X-Trace identifier to be continued.
      # * +opts+   - (optional) hash containing key/value pairs that will be reported with this span.
      #
      # === Example:
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
      # === Returns:
      # * The result of the block.
      #
      def start_trace(span, xtrace = nil, opts = {})
        start_trace_with_target(span, xtrace, {}, opts) { yield }
      end

      # Collect metrics, trace a given block of code, and assign trace info to target.
      #
      # This will start a trace depending on configuration and probability, detect any exceptions
      # thrown by the block, report errors, and assign an X-Trace to the target.
      #
      # The motivating use case for this is HTTP streaming in rails3. We need
      # access to the exit event's trace id so we can set the header before any
      # work is done, and before any headers are sent back to the client.
      #
      # === Arguments:
      # * +span+   - The span the block of code belongs to.
      # * +xtrace+ - (optional) incoming X-Trace identifier to be continued.
      # * +target+ - (optional) has to respond to #[]=, The target object in which to place the trace information.
      # * +opts+   - (optional) hash containing key/value pairs that will be reported with this span.
      #
      # === Example:
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
      # === Returns:
      # * The result of the block.
      #
      def start_trace_with_target(span, xtrace, target, opts = {})
        return yield unless AppOpticsAPM.loaded

        if AppOpticsAPM::Context.isValid # not an entry span!
          result = trace(span) { yield }
          target['X-Trace'] = AppOpticsAPM::Context.toString
          return result
        end

        # :TransactionName and 'TransactionName' need to be removed from opts
        # :TransactionName should only be sent after it is set by send_metrics
        transaction_name = opts.delete('TransactionName')
        transaction_name = opts.delete(:TransactionName) || transaction_name
        # This is the beginning of a transaction, therefore AppOpticsAPM.transaction_name
        # needs to be set to nil or whatever is provided in the opts
        AppOpticsAPM.transaction_name = transaction_name


        AppOpticsAPM::API.log_start(span, xtrace, opts)
        exit_evt = AppOpticsAPM::Context.createEvent
        result = begin
          AppOpticsAPM::API.send_metrics(span, opts) do
            target['X-Trace'] = AppOpticsAPM::EventUtil.metadataString(exit_evt)
            yield
          end
        rescue Exception => e
          AppOpticsAPM::API.log_exception(span, e)
          exit_evt.addEdge(AppOpticsAPM::Context.get)
          xtrace = AppOpticsAPM::API.log_end(span, opts, exit_evt)
          e.instance_variable_set(:@xtrace, xtrace)
          raise
        end

        exit_evt.addEdge(AppOpticsAPM::Context.get)
        AppOpticsAPM::API.log_end(span, opts, exit_evt)

        result
      end

      # Provide a custom transaction name
      #
      # The AppOpticsAPM gem tries to create meaningful transaction names from controller+action
      # or something similar depending on the framework used. However, you may want to override the
      # transaction name to better describe your instrumented operation.
      #
      # Take note that on the dashboard the transaction name is converted to lowercase, and might be
      # truncated with invalid characters replaced. Method calls with an empty string or a non-string
      # argument won't change the current transaction name.
      #
      # The configuration +AppOpticsAPM.Config+['transaction_name']+['prepend_domain']+ can be set to
      # true to have the domain name prepended to the transaction name. This is a global setting.
      #
      # === Argument:
      #
      # * +name+ - A non-empty string with the custom transaction name
      #
      # === Example:
      #
      #   class DogfoodsController < ApplicationController
      #
      #     def create
      #       @dogfood = Dogfood.new(params.permit(:brand, :name))
      #       @dogfood.save
      #
      #       AppOpticsAPM::SDK.set_transaction_name("dogfoodscontroller.create_for_#{params[:brand]}")
      #
      #       redirect_to @dogfood
      #     end
      #
      #   end
      #
      # === Returns:
      # * (String or nil) the current transaction name
      #
      def set_transaction_name(name)
        if name.is_a?(String) && name.strip != ''
          AppOpticsAPM.transaction_name = name
        else
          AppOpticsAPM.logger.debug "[appoptics_apm/api] Could not set transaction name, provided name is empty or not a String."
        end
        AppOpticsAPM.transaction_name
      end


      # Get the currently set custom transaction name.
      #
      # This is provided for testing
      #
      # === Returns:
      # * (String or nil) the current transaction name
      #
      def get_transaction_name
        AppOpticsAPM.transaction_name
      end

      # Determine if this transaction is being traced.
      #
      # Tracing puts some extra load on a system, therefor not all transaction are traced.
      # The `tracing?` method helps to determine this so that extra work can be avoided when not tracing.
      #
      # === Example:
      #
      #   kvs = expensive_info_gathering_method  if AppOpticsAPM::SDK.tracing?
      #   AppOpticsAPM::SDK.trace('some_span', kvs) do
      #     # this may not create a trace every time it runs
      #     db_request
      #   end
      #
      def tracing?
        AppOpticsAPM.tracing?
      end

      # Wait for AppOptics to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running. Usually AppOptics doesn't block an
      # application while it is starting up.
      #
      # === Argument:
      #
      # * +wait_milliseconds+ (int, default 3000) the maximum time to wait in milliseconds
      #
      # === Example:
      #
      #   unless AppopticsAPM::SDK.appoptics_ready?(10_000)
      #     Logger.info "AppOptics not ready after 10 seconds, no metrics will be sent"
      #   end
      #
      def appoptics_ready?(wait_milliseconds = 3000)
        AppopticsAPM::Context.isReady(wait_milliseconds)
      end
    end

    extend Tracing
  end
end
