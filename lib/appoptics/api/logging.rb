# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Make sure Set is loaded if possible.
begin
  require 'set'
rescue LoadError
  class Set; end
end

module AppOptics
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    #
    module Logging
      ##
      # Public: Report an event in an active trace.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event. See API documentation for reserved labels and usage.
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOptics::API.log('logical_layer', 'entry')
      #   AppOptics::API.log('logical_layer', 'info', { :list_length => 20 })
      #   AppOptics::API.log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, opts = {})
        return unless AppOptics.loaded

        log_event(layer, label, AppOptics::Context.createEvent, opts)
      end

      ##
      # Public: Report an exception.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +exn+ - The exception to report
      # * +kvs+ - Custom params if you want to log extra information
      #
      # ==== Example
      #
      #   begin
      #     my_iffy_method
      #   rescue Exception => e
      #     AppOptics::API.log_exception('rails', e, { user: user_id })
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exn, kvs = {})
        return if !AppOptics.loaded || exn.instance_variable_get(:@oboe_logged)

        unless exn
          AppOptics.logger.debug '[appoptics/debug] log_exception called with nil exception'
          return
        end

        kvs.merge!(:ErrorClass => exn.class.name,
                   :ErrorMsg => exn.message,
                   :Backtrace => exn.backtrace.join("\r\n"))

        exn.instance_variable_set(:@oboe_logged, true)
        log(layer, :error, kvs)
      end

      ##
      # Public: Decide whether or not to start a trace, and report an event
      # appropriately.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +xtrace+ - An xtrace metadata string, or nil.  Used for cross-application tracing.
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOptics::API.log_start(:layer_name, nil, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_start(layer, xtrace = nil, opts = {})
        return if !AppOptics.loaded || (opts.key?(:URL) && ::AppOptics::Util.static_asset?(opts[:URL]))

        # Is the below necessary? Only on JRuby? Could there be an existing context but not x-trace header?
        # See discussion at:
        # https://github.com/librato/ruby-tracelytics/pull/6/files?diff=split#r131029135
        #
        # Used by JRuby/Java webservers such as Tomcat
        # AppOptics::Context.fromString(xtrace) if AppOptics.pickup_context?(xtrace)

        # if AppOptics.tracing?
        #   # Pre-existing context.  Either we inherited context from an
        #   # incoming X-Trace request header or under JRuby, Joboe started
        #   # tracing before the JRuby code was called (e.g. Tomcat)
        #   AppOptics.is_continued_trace = true

        #   if AppOptics.has_xtrace_header
        #     opts[:TraceOrigin] = :continued_header
        #   elsif AppOptics.has_incoming_context
        #     opts[:TraceOrigin] = :continued_context
        #   else
        #     opts[:TraceOrigin] = :continued
        #   end

        # return log_entry(layer, opts)
        # end

        if AppOptics.sample?(opts.merge(:layer => layer, :xtrace => xtrace))
          # Yes, we're sampling this request
          # Probablistic tracing of a subset of requests based off of
          # sample rate and sample source
          opts[:SampleRate]        = AppOptics.sample_rate
          opts[:SampleSource]      = AppOptics.sample_source
          opts[:TraceOrigin]       = :always_sampled

          if xtrace_v2?(xtrace)
            # continue valid incoming xtrace
            # use it for current context, ensuring sample bit is set
            AppOptics::XTrace.set_sampled(xtrace)

            md = AppOptics::Metadata.fromString(xtrace)
            AppOptics::Context.fromString(xtrace)
            log_event(layer, :entry, md.createEvent, opts)
          else
            # discard invalid incoming xtrace
            # create a new context, ensuring sample bit set
            md = AppOptics::Metadata.makeRandom(true)
            AppOptics::Context.set(md)
            log_event(layer, :entry, AppOptics::Event.startTrace(md), opts)
          end
        else
          # No, we're not sampling this request
          # set the context but don't log the event
          if xtrace_v2?(xtrace)
            # continue valid incoming xtrace
            # use it for current context, ensuring sample bit is not set
            AppOptics::XTrace.unset_sampled(xtrace)
            AppOptics::Context.fromString(xtrace)
          else
            # discard invalid incoming xtrace
            # create a new context, ensuring sample bit not set
            md = AppOptics::Metadata.makeRandom(false)
            AppOptics::Context.fromString(md.toString)
          end
        end
        AppOptics::Context.toString
      end

      ##
      # Public: Report an exit event and potentially clear the tracing context.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOptics::API.log_end(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_end(layer, opts = {})
        return unless AppOptics.loaded

        log_event(layer, :exit, AppOptics::Context.createEvent, opts)
        xtrace = AppOptics::Context.toString
        AppOptics::Context.clear unless AppOptics.has_incoming_context?
        xtrace
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an entry event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   AppOptics::API.log_entry(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_entry(layer, kvs = {}, op = nil)
        return unless AppOptics.loaded

        AppOptics.layer_op = op.to_sym if op
        log_event(layer, :entry, AppOptics::Context.createEvent, kvs)
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an info event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   AppOptics::API.log_info(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_info(layer, kvs = {})
        return unless AppOptics.loaded

        log_event(layer, :info, AppOptics::Context.createEvent, kvs)
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an exit event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   AppOptics::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string (TODO: does it?)
      def log_exit(layer, kvs = {}, op = nil)
        return unless AppOptics.loaded

        AppOptics.layer_op = nil if op
        log_event(layer, :exit, AppOptics::Context.createEvent, kvs)
      end

      ##
      # Public: Log an exit event from multiple requests
      #
      # A helper method to create and log an info event
      # If we return from a request that faned out multiple requests
      # we can add the collected X-Traces to the exit event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +traces+ - An array with X-Trace strings returned from the requests
      #
      def log_multi_exit(layer, traces)
        return unless AppOptics.loaded
        task_id = AppOptics::XTrace.task_id(AppOptics::Context.toString)
        event = AppOptics::Context.createEvent
        traces.each do |trace|
          event.addEdgeStr(trace) if AppOptics::XTrace.task_id(trace) == task_id
        end
        log_event(layer, :exit, event)
      end

      ##
      # Internal: Report an event.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event.  See API documentation for reserved labels and usage.
      # * +event+ - The pre-existing AppOptics context event.  See AppOptics::Context.createEvent
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   entry = AppOptics::Context.createEvent
      #   AppOptics::API.log_event(:layer_name, 'entry',  entry_event, { :id => @user.id })
      #
      #   exit_event = AppOptics::Context.createEvent
      #   exit_event.addEdge(entry.getMetadata)
      #   AppOptics::API.log_event(:layer_name, 'exit',  exit_event, { :id => @user.id })
      #
      def log_event(layer, label, event, opts = {})
        return unless AppOptics.loaded

        event.addInfo(APPOPTICS_STR_LAYER, layer.to_s.freeze) if layer
        event.addInfo(APPOPTICS_STR_LABEL, label.to_s.freeze)

        AppOptics.layer = layer.to_sym if label == :entry
        AppOptics.layer = nil          if label == :exit

        opts.each do |k, v|
          value = nil

          next unless valid_key? k

          if [Integer, Float, Fixnum, NilClass, String].include?(v.class)
            value = v
          elsif v.class == Set
            value = v.to_a.to_s
          else
            value = v.to_s if v.respond_to?(:to_s)
          end

          begin
            event.addInfo(k.to_s, value)
          rescue ArgumentError => e
            AppOptics.logger.debug "[AppOptics/debug] Couldn't add event KV: #{k} => #{v.class}"
            AppOptics.logger.debug "[AppOptics/debug] #{e.message}"
          end
        end if !opts.nil? && opts.any?

        AppOptics::Reporter.sendReport(event)
      end

      ##
      # Internal: Reports agent init to the collector
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event
      def log_init(layer = :rack, opts = {})
        context = AppOptics::Metadata.makeRandom
        if !context.isValid
          return
        end

        event = context.createEvent
        event.addInfo(APPOPTICS_STR_LAYER, layer.to_s)
        event.addInfo(APPOPTICS_STR_LABEL, 'single')
        opts.each do |k, v|
          event.addInfo(k, v.to_s)
        end

        AppOptics::Reporter.sendStatus(event, context)
      end
    end
  end
end
