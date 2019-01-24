#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

# Make sure Set is loaded if possible.
begin
  require 'set'
rescue LoadError
  class Set; end # :nodoc:
end


module AppOpticsAPM
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    #
    # These are the lower level methods, please see AppOpticsAPM::SDK
    # for the higher level methods
    #
    # If using these directly make sure to always match a start/end and entry/exit to
    # avoid broken traces.
    module Logging
      @@ints_or_nil = [Integer, Float, NilClass, String]
      @@ints_or_nil << Fixnum unless RUBY_VERSION >= '2.4'

      ##
      # Public: Report an event in an active trace.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event. See SDK documentation for reserved labels and usage.
      # * +opts+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +event+ - An event to be used instead of generating a new one (see also start_trace_with_target)
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log('logical_layer', 'entry')
      #   AppOpticsAPM::API.log('logical_layer', 'info', { :list_length => 20 })
      #   AppOpticsAPM::API.log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, opts = {}, event = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        event ||= AppOpticsAPM::Context.createEvent
        log_event(layer, label, event, opts)
      end

      ##
      # Public: Report an exception.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +exception+ - The exception to report
      # * +opts+ - Custom params if you want to log extra information
      #
      # ==== Example
      #
      #   begin
      #     my_iffy_method
      #   rescue Exception => e
      #     AppOpticsAPM::API.log_exception('rails', e, { user: user_id })
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exception, opts = {})
        return AppOpticsAPM::Context.toString if !AppOpticsAPM.tracing? || exception.instance_variable_get(:@exn_logged)

        unless exception
          AppOpticsAPM.logger.debug '[appoptics_apm/debug] log_exception called with nil exception'
          return AppOpticsAPM::Context.toString
        end

        exception.message << exception.class.name if exception.message.length < 4
        opts.merge!(:Spec => 'error',
                    :ErrorClass => exception.class.name,
                    :ErrorMsg => exception.message)
        opts.merge!(:Backtrace => exception.backtrace.join("\r\n")) if exception.backtrace

        exception.instance_variable_set(:@exn_logged, true)
        log(layer, :error, opts)
      end

      ##
      # Public: Decide whether or not to start a trace, and report an entry event
      # appropriately.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +xtrace+ - An xtrace metadata string, or nil.  Used for cross-application tracing.
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_start(:layer_name, nil, { :id => @user.id })
      #
      # Returns an xtrace metadata string if we are tracing
      def log_start(layer, xtrace = nil, opts = {})
        return if !AppOpticsAPM.loaded || (opts.key?(:URL) && AppOpticsAPM::Util.dnt?(opts[:URL]))

        #--
        # Is the below necessary? Only on JRuby? Could there be an existing context but not x-trace header?
        # See discussion at:
        # https://github.com/librato/ruby-tracelytics/pull/6/files?diff=split#r131029135
        #
        # Used by JRuby/Java webservers such as Tomcat
        # AppOpticsAPM::Context.fromString(xtrace) if AppOpticsAPM.pickup_context?(xtrace)

        # if AppOpticsAPM.tracing?
        #   # Pre-existing context.  Either we inherited context from an
        #   # incoming X-Trace request header or under JRuby, Joboe started
        #   # tracing before the JRuby code was called (e.g. Tomcat)
        #   AppOpticsAPM.is_continued_trace = true

        #   if AppOpticsAPM.has_xtrace_header
        #     opts[:TraceOrigin] = :continued_header
        #   elsif AppOpticsAPM.has_incoming_context
        #     opts[:TraceOrigin] = :continued_context
        #   else
        #     opts[:TraceOrigin] = :continued
        #   end

        # return log_entry(layer, opts)
        # end
        #++

        # This is a bit ugly, but here is the best place to reset the layer_op thread local var.
        AppOpticsAPM.layer_op = nil unless AppOpticsAPM::Context.isValid

        if AppOpticsAPM.sample?(opts.merge(:xtrace => xtrace))
          # Yes, we're sampling this request
          # Probablistic tracing of a subset of requests based off of
          # sample rate and sample source
          opts[:SampleRate]        = AppOpticsAPM.sample_rate
          opts[:SampleSource]      = AppOpticsAPM.sample_source
          opts[:TraceOrigin]       = :always_sampled

          if xtrace_v2?(xtrace)
            # continue valid incoming xtrace
            # use it for current context, ensuring sample bit is set
            AppOpticsAPM::XTrace.set_sampled(xtrace)

            md = AppOpticsAPM::Metadata.fromString(xtrace)
            AppOpticsAPM::Context.fromString(xtrace)
            log_event(layer, :entry, md.createEvent, opts)
          else
            # discard invalid incoming xtrace
            # create a new context, ensuring sample bit set
            md = AppOpticsAPM::Metadata.makeRandom(true)
            AppOpticsAPM::Context.set(md)
            log_event(layer, :entry, AppOpticsAPM::Event.startTrace(md), opts)
          end
        else
          # No, we're not sampling this request
          # set the context but don't log the event
          if xtrace_v2?(xtrace)
            # continue valid incoming xtrace
            # use it for current context, ensuring sample bit is not set
            AppOpticsAPM::XTrace.unset_sampled(xtrace)
            AppOpticsAPM::Context.fromString(xtrace)
          else
            # discard invalid incoming xtrace
            # create a new context, ensuring sample bit not set
            md = AppOpticsAPM::Metadata.makeRandom(false)
            AppOpticsAPM::Context.fromString(md.toString)
          end
        end
        AppOpticsAPM::Context.toString
      end

      ##
      # Public: Report an exit event and potentially clear the tracing context.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_end(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string if we are tracing
      def log_end(layer, opts = {}, event = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        event ||= AppOpticsAPM::Context.createEvent
        log_event(layer, :exit, event, opts)
      ensure
        # FIXME has_incoming_context commented out, it has importance for JRuby only but breaks Ruby tests
        AppOpticsAPM::Context.clear # unless AppOpticsAPM.has_incoming_context?
        AppOpticsAPM.transaction_name = nil
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an entry event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_entry(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string if we are tracing
      def log_entry(layer, opts = {}, op = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        AppOpticsAPM.layer_op = (AppOpticsAPM.layer_op || []) << op.to_sym if op
        log_event(layer, :entry, AppOpticsAPM::Context.createEvent, opts)
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an info event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_info(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string if we are tracing
      def log_info(layer, opts = {})
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        log_event(layer, :info, AppOpticsAPM::Context.createEvent, opts)
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an exit event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+    - Used to avoid double tracing recursive calls, needs to be true in +log_exit+ that corresponds to a
      #   +log_entry+
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string  if we are tracing
      def log_exit(layer, opts = {}, op = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        AppOpticsAPM.layer_op.pop if op && AppOpticsAPM.layer_op.is_a?(Array) && AppOpticsAPM.layer_op.last == op.to_sym

        log_event(layer, :exit, AppOpticsAPM::Context.createEvent, opts)
      end

      ##
      # Public: Log an exit event from multiple requests
      #
      # A helper method to create and log an info event
      # If we return from a request that faned out multiple requests
      # we can add the collected X-Traces to the exit event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +traces+ - An array with X-Trace strings returned from the requests
      #
      def log_multi_exit(layer, traces)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?
        task_id = AppOpticsAPM::XTrace.task_id(AppOpticsAPM::Context.toString)
        event = AppOpticsAPM::Context.createEvent
        traces.each do |trace|
          event.addEdgeStr(trace) if AppOpticsAPM::XTrace.task_id(trace) == task_id
        end
        log_event(layer, :exit, event)
      end

      ##
      #:nodoc:
      # Internal: Reports agent init to the collector
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event
      def log_init(layer = :rack, opts = {})
        context = AppOpticsAPM::Metadata.makeRandom
        return AppOpticsAPM::Context.toString unless context.isValid

        event = context.createEvent
        event.addInfo(APPOPTICS_STR_LAYER, layer.to_s)
        event.addInfo(APPOPTICS_STR_LABEL, 'single')
        opts.each do |k, v|
          event.addInfo(k, v.to_s)
        end

        AppOpticsAPM::Reporter.sendStatus(event, context)
        AppOpticsAPM::Context.toString
      end

      private

      ##
      #:nodoc:
      # @private
      # Internal: Report an event.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event.  See API documentation for reserved labels and usage.
      # * +event+ - The pre-existing AppOpticsAPM context event.  See AppOpticsAPM::Context.createEvent
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   entry = AppOpticsAPM::Context.createEvent
      #   AppOpticsAPM::API.log_event(:layer_name, 'entry',  entry_event, { :id => @user.id })
      #
      #   exit_event = AppOpticsAPM::Context.createEvent
      #   exit_event.addEdge(entry.getMetadata)
      #   AppOpticsAPM::API.log_event(:layer_name, 'exit',  exit_event, { :id => @user.id })
      #
      def log_event(layer, label, event, opts = {})
        event.addInfo(APPOPTICS_STR_LAYER, layer.to_s.freeze) if layer
        event.addInfo(APPOPTICS_STR_LABEL, label.to_s.freeze)

        AppOpticsAPM.layer = layer.to_sym if label == :entry
        AppOpticsAPM.layer = nil          if label == :exit

        opts.each do |k, v|
          value = nil

          next unless valid_key? k

          if @@ints_or_nil.include?(v.class)
            value = v
          elsif v.class == Set
            value = v.to_a.to_s
          else
            value = v.to_s if v.respond_to?(:to_s)
          end

          begin
            event.addInfo(k.to_s, value)
          rescue ArgumentError => e
            AppOpticsAPM.logger.debug "[appoptics_apm/debug] Couldn't add event KV: #{k} => #{v.class}"
            AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{e.message}"
          end
        end if !opts.nil? && opts.any?

        AppOpticsAPM::Reporter.sendReport(event)
        AppOpticsAPM::Context.toString
      end

      # need to set the context to public, otherwise the following `extends` will be private in api.rb
      public

    end
  end
end
