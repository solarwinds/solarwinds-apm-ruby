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
    # * +AppOpticsAPM::SDK.trace_method+
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
        opts[:Backtrace] && opts.delete(:Backtrace) # to avoid sending backtrace twice (faster to check presence here)
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
      #     AppOpticsAPM::SDK.start_trace('custom_trace', nil, :TransactionName => 'handle_request') do
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
      #     AppOpticsAPM::SDK.start_trace_with_target('rails', request['X-Trace'], response) do
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
        opts[:Backtrace] && opts.delete(:Backtrace) # to avoid sending backtrace twice (faster to check presence here)

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

      ##
      # Add tracing to a given method
      #
      # This instruments the given method so that every time it is called it
      # will create a span depending on the current context.
      #
      # The method can be of any (accessible) type (instance, singleton,
      # private, protected etc.).
      #
      # The motivating use case for this is MetalController methods in Rails,
      # which can't be auto-instrumented.
      #
      # === Arguments:
      # * +klass+  - The module/class the method belongs to.
      # * +method+ - The method name as symbol
      # * +config+   - (optional) possible keys are:
      #              :name the name of the span (default: the method name)
      #              :backtrace true/false (default: false) if true the backtrace will be added to the space
      # * +opts+    - (optional) hash containing key/value pairs that will be reported with this span.
      #
      # === Example:
      #
      #   module ExampleModule
      #     def do_sum(a, b)
      #       a + b
      #     end
      #   end
      #
      #  AppOpticsAPM::SDK.trace_method(ExampleModule, :do_sum, {name: 'computation', backtrace: true}, { CustomKey: "some_info"})
      #
      def trace_method(klass, method, config = {}, opts = {})
        # If we're on an unsupported platform (ahem Mac), just act
        # like we did something to nicely play the no-op part.
        return true unless AppOpticsAPM.loaded

        if !klass.is_a?(Module)
          AppOpticsAPM.logger.warn "[appoptics_apm/error] trace_method: Not sure what to do with #{klass}.  Send a class or module."
          return false
        end

        if method.is_a?(String)
          method = method.to_sym
        elsif !method.is_a?(Symbol)
          AppOpticsAPM.logger.warn "[appoptics_apm/error] trace_method: Not sure what to do with #{method}.  Send a string or symbol for method."
          return false
        end

        instance_method = klass.instance_methods.include?(method) || klass.private_instance_methods.include?(method)
        class_method = klass.singleton_methods.include?(method)

        # Make sure the request klass::method exists
        if !instance_method && !class_method
          AppOpticsAPM.logger.warn "[appoptics_apm/error] trace_method: Can't instrument #{klass}.#{method} as it doesn't seem to exist."
          AppOpticsAPM.logger.warn "[appoptics_apm/error] #{__FILE__}:#{__LINE__}"
          return false
        end

        # Strip '!' or '?' from method if present
        safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
        safe_method_name ||= method

        without_appoptics = "#{safe_method_name}_without_appoptics"
        with_appoptics    = "#{safe_method_name}_with_appoptics"

        # Check if already profiled
        if instance_method && klass.instance_methods.include?(with_appoptics.to_sym) ||
          class_method && klass.singleton_methods.include?(with_appoptics.to_sym)
          AppOpticsAPM.logger.warn "[appoptics_apm/error] trace_method: #{klass}::#{method} already instrumented.\n#{__FILE__}:#{__LINE__}"
          return false
        end

        report_kvs = opts.dup
        if defined?(::AbstractController::Base) && klass.ancestors.include?(::AbstractController::Base)
          report_kvs[:Controller] = klass.to_s
          report_kvs[:Action] = method.to_s
        else
          klass.is_a?(Class) ? report_kvs[:Class] = klass.to_s : report_kvs[:Module] = klass.to_s
          report_kvs[:MethodName] = safe_method_name
        end
        backtrace = config[:backtrace]

        span = config[:name] || method
        if instance_method
          klass.class_eval do
            define_method(with_appoptics) do |*args, &block|
              # if this is a rails controller we want to set the transaction for the outbound metrics
              if report_kvs[:Controller] && defined?(request) && defined?(request.env)
                request.env['appoptics_apm.controller'] = report_kvs[:Controller]
                request.env['appoptics_apm.action'] = report_kvs[:Action]
              end

              AppOpticsAPM::SDK.trace(span, report_kvs) do
                report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if backtrace
                send(without_appoptics, *args, &block)
              end
            end

            alias_method without_appoptics, method.to_s
            alias_method method.to_s, with_appoptics
          end
        elsif class_method
          klass.define_singleton_method(with_appoptics) do |*args, &block|
            AppOpticsAPM::SDK.trace(span, report_kvs) do
              report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if backtrace
              send(without_appoptics, *args, &block)
            end
          end

          klass.singleton_class.class_eval do
            alias_method without_appoptics, method.to_s
            alias_method method.to_s, with_appoptics
          end
        end
        true
      end

      ##
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

  end
end
