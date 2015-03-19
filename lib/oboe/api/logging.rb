# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    module Logging
      # Public: Report an event in an active trace.
      #
      # layer - The layer the reported event belongs to
      # label - The label for the reported event. See API documentation for
      #         reserved labels and usage.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Example
      #
      #   log('logical_layer', 'entry')
      #   log('logical_layer', 'info', { :list_length => 20 })
      #   log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, opts = {})
        if Oboe.loaded
          log_event(layer, label, Oboe::Context.createEvent, opts)
        end
      end

      # Public: Report an exception.
      #
      # layer - The layer the reported event belongs to
      # exn - The exception to report
      #
      # Example
      #
      #   begin
      #     function_without_oboe()
      #   rescue Exception => e
      #     log_exception('rails', e)
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exn)
        return if !Oboe.loaded || exn.instance_variable_get(:@oboe_logged)

        kvs = { :ErrorClass => exn.class.name,
                :ErrorMsg => exn.message,
                :Backtrace => exn.backtrace.join("\r\n") }

        exn.instance_variable_set(:@oboe_logged, true)
        log(layer, 'error', kvs)
      end

      # Public: Decide whether or not to start a trace, and report an event
      # appropriately.
      #
      # layer - The layer the reported event belongs to
      # xtrace - An xtrace metadata string, or nil.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Returns nothing.
      def log_start(layer, xtrace, opts = {})
        return if !Oboe.loaded || Oboe.never? ||
                  (opts.key?(:URL) && ::Oboe::Util.static_asset?(opts[:URL]))

        Oboe::Context.fromString(xtrace) if Oboe.pickup_context?(xtrace)

        if Oboe.tracing?
          # Pre-existing context.  Either we inherited context from an
          # incoming X-Trace request header or under JRuby, Joboe started
          # tracing before the JRuby code was called (e.g. Tomcat)
          Oboe.is_continued_trace = true

          if Oboe.has_xtrace_header
            opts[:TraceOrigin] = :continued_header
          elsif Oboe.has_incoming_context
            opts[:TraceOrigin] = :continued_context
          else
            opts[:TraceOrigin] = :continued
          end

          log_entry(layer, opts)

        elsif opts.key?('Force')
          # Forced tracing: used by __Init reporting
          opts[:TraceOrigin] = :forced
          log_event(layer, 'entry', Oboe::Context.startTrace, opts)

        elsif Oboe.sample?(opts.merge(:layer => layer, :xtrace => xtrace))
          # Probablistic tracing of a subset of requests based off of
          # sample rate and sample source
          opts[:SampleRate]        = Oboe.sample_rate
          opts[:SampleSource]      = Oboe.sample_source
          opts[:TraceOrigin] = :always_sampled

          log_event(layer, 'entry', Oboe::Context.startTrace, opts)
        end
      end

      # Public: Report an exit event.
      #
      # layer - The layer the reported event belongs to
      #
      # Returns an xtrace metadata string
      def log_end(layer, opts = {})
        if Oboe.loaded
          log_event(layer, 'exit', Oboe::Context.createEvent, opts)
          xtrace = Oboe::Context.toString
          Oboe::Context.clear unless Oboe.has_incoming_context?
          xtrace
        end
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an
      # entry event
      #
      # Returns an xtrace metadata string
      def log_entry(layer, kvs = {}, op = nil)
        if Oboe.loaded
          Oboe.layer_op = op if op
          log_event(layer, 'entry', Oboe::Context.createEvent, kvs)
        end
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an
      # info event
      #
      # Returns an xtrace metadata string
      def log_info(layer, kvs = {})
        if Oboe.loaded
          log_event(layer, 'info', Oboe::Context.createEvent, kvs)
        end
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an
      # exit event
      #
      # Returns an xtrace metadata string
      def log_exit(layer, kvs = {}, op = nil)
        if Oboe.loaded
          Oboe.layer_op = nil if op
          log_event(layer, 'exit', Oboe::Context.createEvent, kvs)
        end
      end

      # Internal: Report an event.
      #
      # layer - The layer the reported event belongs to
      # label - The label for the reported event. See API documentation for
      #         reserved labels and usage.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Examples
      #
      #   entry = Oboe::Context.createEvent
      #   log_event('rails', 'entry', exit, { :controller => 'user', :action => 'index' })
      #   exit = Oboe::Context.createEvent
      #   exit.addEdge(entry.getMetadata)
      #   log_event('rails', 'exit', exit)
      #
      # Returns nothing.
      def log_event(layer, label, event, opts = {})
        if Oboe.loaded
          event.addInfo('Layer', layer.to_s) if layer
          event.addInfo('Label', label.to_s)

          Oboe.layer = layer if label == 'entry'
          Oboe.layer = nil   if label == 'exit'

          opts.each do |k, v|
            value = nil

            if valid_key? k
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
                Oboe.logger.debug "[oboe/debug] Couldn't add event KV: #{k.to_s} => #{v.class}"
              end
            end
          end if !opts.nil? && opts.any?

          Oboe::Reporter.sendReport(event)
        end
      end
    end
  end
end
