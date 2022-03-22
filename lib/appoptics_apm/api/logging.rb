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

module SolarWindsAPM
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    #
    # These are the lower level methods, please see SolarWindsAPM::SDK
    # for the higher level methods
    #
    # If using these directly make sure to always match a start/end and entry/exit to
    # avoid broken traces.
    module Logging
      @@ints_or_nil = [Integer, Float, NilClass, String]

      ##
      # Public: Report an event in an active trace.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event. See SDK documentation for reserved labels and usage.
      # * +kvs+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +event+ - An event to be used instead of generating a new one (see also start_trace_with_target)
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log('logical_layer', 'entry')
      #   SolarWindsAPM::API.log('logical_layer', 'info', { :list_length => 20 })
      #   SolarWindsAPM::API.log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, kvs = {}, event = nil)
        return SolarWindsAPM::Context.toString unless SolarWindsAPM.tracing?

        event ||= SolarWindsAPM::Context.createEvent
        log_event(layer, label, event, kvs)
      end

      ##
      # Public: Report an exception.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +exception+ - The exception to report, responds to :message and :backtrace(optional)
      # * +kvs+ - Custom params if you want to log extra information
      #
      # ==== Example
      #
      #   begin
      #     my_iffy_method
      #   rescue Exception => e
      #     SolarWindsAPM::API.log_exception('rails', e, { user: user_id })
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exception, kvs = {})
        return SolarWindsAPM::Context.toString if !SolarWindsAPM.tracing? || exception.instance_variable_get(:@exn_logged)

        unless exception
          SolarWindsAPM.logger.debug '[appoptics_apm/debug] log_exception called with nil exception'
          return SolarWindsAPM::Context.toString
        end

        exception.message << exception.class.name if exception.message.length < 4
        kvs.merge!(:Spec => 'error',
                    :ErrorClass => exception.class.name,
                    :ErrorMsg => exception.message)

        if exception.respond_to?(:backtrace) && exception.backtrace
          kvs.merge!(:Backtrace => exception.backtrace.join("\r\n"))
        end

        exception.instance_variable_set(:@exn_logged, true)
        log(layer, :error, kvs)
      end

      ##
      # Public: Start a trace depending on TransactionSettings
      # or decide whether or not to start a trace, and report an entry event
      # appropriately.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +headers+ - the request headers, they may contain w3c trace_context data
      # * +settings+ - An instance of TransactionSettings
      # * +url+ - String of the current url, it may be configured to be excluded from tracing
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log_start(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_start(layer, kvs = {}, headers = {}, settings = nil, url = nil)
        return unless SolarWindsAPM.loaded

        # check if tracing decision is already in effect and a Context created
        return log_entry(layer, kvs) if SolarWindsAPM::Context.isValid

        # This is a bit ugly, but here is the best place to reset the layer_op thread local var.
        SolarWindsAPM.layer_op = nil

        settings ||= SolarWindsAPM::TransactionSettings.new(url, headers)
        SolarWindsAPM.trace_context.add_kvs(kvs)
        tracestring = SolarWindsAPM.trace_context.tracestring

        if settings.do_sample
          kvs[:SampleRate]        = settings.rate
          kvs[:SampleSource]      = settings.source

          SolarWindsAPM::TraceString.set_sampled(tracestring) if tracestring
          event = create_start_event(tracestring)
          log_event(layer, :entry, event, kvs)
        else
          create_nontracing_context(tracestring)
          SolarWindsAPM::Context.toString
        end
      end

      ##
      # Public: Report an exit event and potentially clear the tracing context.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log_end(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_end(layer, kvs = {}, event = nil)
        return SolarWindsAPM::Context.toString unless SolarWindsAPM.tracing?

        event ||= SolarWindsAPM::Context.createEvent
        log_event(layer, :exit, event, kvs)
      ensure
        # FIXME has_incoming_context commented out, it has importance for JRuby only but breaks Ruby tests
        SolarWindsAPM::Context.clear # unless SolarWindsAPM.has_incoming_context?
        SolarWindsAPM.trace_context = nil
        SolarWindsAPM.transaction_name = nil
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an entry event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log_entry(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string
      #
      def log_entry(layer, kvs = {}, op = nil)
        return SolarWindsAPM::Context.toString unless SolarWindsAPM.tracing?

        if op
          # check if re-entry but also add op to list for log_exit
          re_entry = SolarWindsAPM.layer_op&.last == op.to_sym
          SolarWindsAPM.layer_op = (SolarWindsAPM.layer_op || []) << op.to_sym
          return SolarWindsAPM::Context.toString if re_entry
        end

        event ||= SolarWindsAPM::Context.createEvent
        log_event(layer, :entry, event, kvs)
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an info event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log_info(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_info(layer, kvs = {})
        return SolarWindsAPM::Context.toString unless SolarWindsAPM.tracing?

        kvs[:Spec] = 'info'
        log_event(layer, :info, SolarWindsAPM::Context.createEvent, kvs)
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an exit event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+    - Used to avoid double tracing recursive calls, needs to be the same in +log_exit+ that corresponds to a
      #   +log_entry+
      #
      # ==== Example
      #
      #   SolarWindsAPM::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string  if we are tracing
      def log_exit(layer, kvs = {}, op = nil)
        return SolarWindsAPM::Context.toString unless SolarWindsAPM.tracing?

        if op
          if SolarWindsAPM.layer_op&.last == op.to_sym
            SolarWindsAPM.layer_op.pop
          else
            SolarWindsAPM.logger.warn "[ruby/logging] op parameter of exit event doesn't correspond to an entry event op"
          end
          # check if the next op is the same, don't log event if so
          return SolarWindsAPM::Context.toString if SolarWindsAPM.layer_op&.last == op.to_sym
        end

        log_event(layer, :exit, SolarWindsAPM::Context.createEvent, kvs)
      end

      ##
      #:nodoc:
      # Internal: Reports agent init to the collector
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event
      def log_init(layer = :rack, kvs = {})
        context = SolarWindsAPM::Metadata.makeRandom
        return SolarWindsAPM::Context.toString unless context.isValid

        event = context.createEvent
        event.addInfo(SW_AMP_STR_LAYER, layer.to_s)
        event.addInfo(SW_AMP_STR_LABEL, 'single')
        kvs.each do |k, v|
          event.addInfo(k, v.to_s)
        end

        SolarWindsAPM::Reporter.sendStatus(event, context)
        SolarWindsAPM::Context.toString
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
      # * +event+ - The pre-existing SolarWindsAPM context event.  See SolarWindsAPM::Context.createEvent
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   entry = SolarWindsAPM::Context.createEvent
      #   SolarWindsAPM::API.log_event(:layer_name, 'entry',  entry_event, { :id => @user.id })
      #
      #   exit_event = SolarWindsAPM::Context.createEvent
      #   exit_event.addEdge(entry.getMetadata)
      #   SolarWindsAPM::API.log_event(:layer_name, 'exit',  exit_event, { :id => @user.id })
      #
      def log_event(layer, label, event, kvs = {})
        event.addInfo(SW_AMP_STR_LAYER, layer.to_s.freeze) if layer
        event.addInfo(SW_AMP_STR_LABEL, label.to_s.freeze)

        SolarWindsAPM.layer = layer.to_sym if label == :entry
        SolarWindsAPM.layer = nil          if label == :exit

        kvs.each do |k, v|
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
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] Couldn't add event KV: #{k} => #{v.class}"
            SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{e.message}"
          end
        end if !kvs.nil? && kvs.any?

        SolarWindsAPM::Reporter.sendReport(event)
        SolarWindsAPM::Context.toString
      end

      def create_start_event(tracestring = nil)
        if SolarWindsAPM::TraceString.sampled?(tracestring)
          md = SolarWindsAPM::Metadata.fromString(tracestring)
          SolarWindsAPM::Context.fromString(tracestring)
          md.createEvent
        else
          md = SolarWindsAPM::Metadata.makeRandom(true)
          SolarWindsAPM::Context.set(md)
          SolarWindsAPM::Event.startTrace(md)
        end
      end

      public

      def create_nontracing_context(tracestring)
        if SolarWindsAPM::TraceString.valid?(tracestring)
          # continue valid incoming tracestring
          # use it for current context, ensuring sample bit is not set
          SolarWindsAPM::TraceString.unset_sampled(tracestring)
          SolarWindsAPM::Context.fromString(tracestring)
        else
          # discard invalid incoming tracestring
          # create a new context, ensuring sample bit not set
          md = SolarWindsAPM::Metadata.makeRandom(false)
          SolarWindsAPM::Context.fromString(md.toString)
        end
      end

      # need to set the module context to public, otherwise the following `extends` will be private in api.rb

      public

    end
  end
end
