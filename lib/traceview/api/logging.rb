# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
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
        if TraceView.loaded
          log_event(layer, label, TraceView::Context.createEvent, opts)
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
      #     function_without_traceview()
      #   rescue Exception => e
      #     log_exception('rails', e)
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exn)
        return if !TraceView.loaded || exn.instance_variable_get(:@oboe_logged)

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
      def log_start(layer, xtrace = nil, opts = {})
        return if !TraceView.loaded || TraceView.never? ||
                  (opts.key?(:URL) && ::TraceView::Util.static_asset?(opts[:URL]))

        TraceView::Context.fromString(xtrace) if TraceView.pickup_context?(xtrace)

        if TraceView.tracing?
          # Pre-existing context.  Either we inherited context from an
          # incoming X-Trace request header or under JRuby, Joboe started
          # tracing before the JRuby code was called (e.g. Tomcat)
          TraceView.is_continued_trace = true

          if TraceView.has_xtrace_header
            opts[:TraceOrigin] = :continued_header
          elsif TraceView.has_incoming_context
            opts[:TraceOrigin] = :continued_context
          else
            opts[:TraceOrigin] = :continued
          end

          log_entry(layer, opts)

        elsif opts.key?('Force')
          # Forced tracing: used by __Init reporting
          opts[:TraceOrigin] = :forced
          log_event(layer, 'entry', TraceView::Context.startTrace, opts)

        elsif TraceView.sample?(opts.merge(:layer => layer, :xtrace => xtrace))
          # Probablistic tracing of a subset of requests based off of
          # sample rate and sample source
          opts[:SampleRate]        = TraceView.sample_rate
          opts[:SampleSource]      = TraceView.sample_source
          opts[:TraceOrigin] = :always_sampled

          log_event(layer, 'entry', TraceView::Context.startTrace, opts)
        end
      end

      # Public: Report an exit event.
      #
      # layer - The layer the reported event belongs to
      #
      # Returns an xtrace metadata string
      def log_end(layer, opts = {})
        if TraceView.loaded
          log_event(layer, 'exit', TraceView::Context.createEvent, opts)
          xtrace = TraceView::Context.toString
          TraceView::Context.clear unless TraceView.has_incoming_context?
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
        if TraceView.loaded
          TraceView.layer_op = op if op
          log_event(layer, 'entry', TraceView::Context.createEvent, kvs)
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
        if TraceView.loaded
          log_event(layer, 'info', TraceView::Context.createEvent, kvs)
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
        if TraceView.loaded
          TraceView.layer_op = nil if op
          log_event(layer, 'exit', TraceView::Context.createEvent, kvs)
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
      #   entry = TraceView::Context.createEvent
      #   log_event('rails', 'entry', exit, { :controller => 'user', :action => 'index' })
      #   exit = TraceView::Context.createEvent
      #   exit.addEdge(entry.getMetadata)
      #   log_event('rails', 'exit', exit)
      #
      # Returns nothing.
      def log_event(layer, label, event, opts = {})
        if TraceView.loaded
          event.addInfo('Layer', layer.to_s) if layer
          event.addInfo('Label', label.to_s)

          TraceView.layer = layer if label == 'entry'
          TraceView.layer = nil   if label == 'exit'

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
                TraceView.logger.debug "[TraceView/debug] Couldn't add event KV: #{k.to_s} => #{v.class}"
                TraceView.logger.debug "[TraceView/debug] #{e.message}"
              end
            end
          end if !opts.nil? && opts.any?

          TraceView::Reporter.sendReport(event)
        end
      end
    end
  end
end
