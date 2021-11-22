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
      # * +exception+ - The exception to report, responds to :message and :backtrace(optional)
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

        if exception.respond_to?(:backtrace) && exception.backtrace
          opts.merge!(:Backtrace => exception.backtrace.join("\r\n"))
        end

        exception.instance_variable_set(:@exn_logged, true)
        log(layer, :error, opts)
      end

      ##
      # Public: Start a trace depending on TransactionSettings
      # or decide whether or not to start a trace, and report an entry event
      # appropriately.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +settings+ - An instance of TransactionSettings
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_start(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_start(layer, opts = {}, settings = nil)
        return unless AppOpticsAPM.loaded

        # check if tracing decision is already in effect and a Context created
        return log_entry(layer, opts) if AppOpticsAPM::Context.isValid

        # This is a bit ugly, but here is the best place to reset the layer_op thread local var.
        AppOpticsAPM.layer_op = nil

        tracestring = AppOpticsAPM.trace_context&.tracestring
        sw_member_value = AppOpticsAPM.trace_context&.sw_member_value
        settings ||= AppOpticsAPM::TransactionSettings.new(nil, tracestring, sw_member_value)

        if settings.do_sample
          opts[:SampleRate]        = settings.rate
          opts[:SampleSource]      = settings.source

          AppOpticsAPM::TraceString.set_sampled(tracestring) if tracestring
          event = create_start_event(tracestring)
          log_event(layer, :entry, event, opts)
        else
          create_nontracing_context(tracestring)
          AppOpticsAPM::Context.toString
        end
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
      # Returns a metadata string if we are tracing
      #
      def log_end(layer, opts = {}, event = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        event ||= AppOpticsAPM::Context.createEvent
        log_event(layer, :exit, event, opts)
      ensure
        # FIXME has_incoming_context commented out, it has importance for JRuby only but breaks Ruby tests
        AppOpticsAPM::Context.clear # unless AppOpticsAPM.has_incoming_context?
        AppOpticsAPM.trace_context = nil
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
      # Returns a metadata string
      #
      def log_entry(layer, opts = {}, op = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        if op
          # check if re-entry but also add op to list for log_exit
          re_entry = AppOpticsAPM.layer_op&.last == op.to_sym
          AppOpticsAPM.layer_op = (AppOpticsAPM.layer_op || []) << op.to_sym
          return AppOpticsAPM::Context.toString if re_entry
        end

        event ||= AppOpticsAPM::Context.createEvent
        log_event(layer, :entry, event, opts)
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
      # Returns a metadata string if we are tracing
      #
      def log_info(layer, opts = {})
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        opts[:Spec] = 'info'
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
      # * +op+    - Used to avoid double tracing recursive calls, needs to be the same in +log_exit+ that corresponds to a
      #   +log_entry+
      #
      # ==== Example
      #
      #   AppOpticsAPM::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string  if we are tracing
      def log_exit(layer, opts = {}, op = nil)
        return AppOpticsAPM::Context.toString unless AppOpticsAPM.tracing?

        if op
          if AppOpticsAPM.layer_op&.last == op.to_sym
            AppOpticsAPM.layer_op.pop
          else
            AppOpticsAPM.logger.warn "[ruby/logging] op parameter of exit event doesn't correspond to an entry event op"
          end
          # check if the next op is the same, don't log event if so
          return AppOpticsAPM::Context.toString if AppOpticsAPM.layer_op&.last == op.to_sym
        end

        log_event(layer, :exit, AppOpticsAPM::Context.createEvent, opts)
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

      def create_start_event(tracestring = nil)
        if AppOpticsAPM::TraceString.sampled?(tracestring)
          md = AppOpticsAPM::Metadata.fromString(tracestring)
          AppOpticsAPM::Context.fromString(tracestring)
          md.createEvent
        else
          md = AppOpticsAPM::Metadata.makeRandom(true)
          AppOpticsAPM::Context.set(md)
          AppOpticsAPM::Event.startTrace(md)
        end
      end

      public

      def create_nontracing_context(tracestring)
        if AppOpticsAPM::TraceString.valid?(tracestring)
          # continue valid incoming tracestring
          # use it for current context, ensuring sample bit is not set
          AppOpticsAPM::TraceString.unset_sampled(tracestring)
          AppOpticsAPM::Context.fromString(tracestring)
        else
          # discard invalid incoming tracestring
          # create a new context, ensuring sample bit not set
          md = AppOpticsAPM::Metadata.makeRandom(false)
          AppOpticsAPM::Context.fromString(md.toString)
        end
      end

      # need to set the module context to public, otherwise the following `extends` will be private in api.rb

      public

    end
  end
end
