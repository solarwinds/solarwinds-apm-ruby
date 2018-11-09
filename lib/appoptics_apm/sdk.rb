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
    # * +:Controller+
    # * +:Action+
    # * +:HTTP-Host+
    # * +:URL+
    # * +:Method+
    #
    # as well as custom keys. The information will show up in the raw data view of a span.
    #
    # Invalid keys: +:Label+, +:Layer+, +:Edge+, +:Timestamp+, +:Timestamp_u+, +:TransactionName+ (allowed in start_trace)
    #
    # The methods are exposed as singleton methods for AppOpticsAPM::SDK.
    #
    # === Usage:
    # * +AppOpticsAPM::SDK.appoptics_ready?+
    # * +AppOpticsAPM::SDK.get_transaction_name+
    # * +AppOpticsAPM::SDK.set_transaction_name+
    # * +AppOpticsAPM::SDK.start_trace+
    # * +AppOpticsAPM::SDK.start_trace_with_target+
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
      #   def computation_with_appoptics(n)
      #     AppOpticsAPM::SDK.trace('computation', { :number => n }, :computation) do
      #       return n if n == 0
      #       n + computation_with_appoptics(n-1)
      #     end
      #   end
      #
      #   result = computation_with_appoptics(100)
      #
      # === Returns:
      # * The result of the block.
      #
      def trace(span, opts = {}, protect_op = nil)
        return yield if !AppOpticsAPM.loaded || !AppOpticsAPM.tracing? || AppOpticsAPM.tracing_layer_op?(protect_op)

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
      #   The value of :TransactionName will set the transaction_name.
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
          result = trace(span, opts) { yield }
          target['X-Trace'] = AppOpticsAPM::Context.toString
          return result
        end

        # :TransactionName and 'TransactionName' need to be removed from opts
        AppOpticsAPM.transaction_name = opts.delete('TransactionName') || opts.delete(:TransactionName)

        AppOpticsAPM::API.log_start(span, xtrace, opts)
        # AppOpticsAPM::Event.startTrace creates an Event without an Edge
        exit_evt = AppOpticsAPM::Event.startTrace(AppOpticsAPM::Context.get)
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
      # true to have the domain name prepended to the transaction name when an event or a metric are
      # logged. This is a global setting.
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
      # * (String or nil) the current transaction name (without domain prepended)
      #
      def get_transaction_name
        AppOpticsAPM.transaction_name
      end

      # Determine if this transaction is being traced.
      #
      # Tracing puts some extra load on a system, therefor not all transaction are traced.
      # The +tracing?+ method helps to determine this so that extra work can be avoided when not tracing.
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
        return false unless AppOpticsAPM.loaded
        # These codes are returned by isReady:
        # OBOE_SERVER_RESPONSE_UNKNOWN 0
        # OBOE_SERVER_RESPONSE_OK 1
        # OBOE_SERVER_RESPONSE_TRY_LATER 2
        # OBOE_SERVER_RESPONSE_LIMIT_EXCEEDED 3
        # OBOE_SERVER_RESPONSE_INVALID_API_KEY 4
        # OBOE_SERVER_RESPONSE_CONNECT_ERROR 5
        AppopticsAPM::Context.isReady(wait_milliseconds) == 1
      end
    end

    extend Tracing

    module CustomMetrics

      # Send counts
      #
      # Use this method to report the number of times an action occurs. The metric counts reported are summed and flushed every 60 seconds.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      def increment_metric(name, count = 1, with_hostname = false, tags_kvs = {})
        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        AppOpticsAPM::CustomMetrics.increment(name.to_s, count, with_hostname, nil, tags, tags_count)
      end

      # Send values for each or multiple counts
      #
      # Use this method to report a value for each or multiple counts. The metric values reported are aggregated and flushed every 60 seconds.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +value+         (Numeric) Value to be added to the current sum
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      def summary_metric(name, value, count = 1, with_hostname = false, tags_kvs = {})
        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        AppOpticsAPM::CustomMetrics.summary(name.to_s, value, count, with_hostname, nil, tags, tags_count)
      end

      private

      def make_tags(tags_kvs)
        unless tags_kvs.is_a?(Hash)
          AppOpticsAPM.logger.warn("[appoptics_apm/metrics] CustomMetrics received tags_kvs that are not a Hash (found #{tags_kvs.class}), setting tags_kvs = {}")
          tags_kvs = {}
        end
        count = tags_kvs.size
        tags = AppOpticsAPM::MetricTags.new(count)

        tags_kvs.each_with_index do |(k, v), i|
          tags.add(i, k.to_s, v.to_s)
        end

        [tags, count]
      end
    end

    extend CustomMetrics
  end
end
