# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  ##
  # Methods to act on, manipulate or investigate an X-Trace
  # value
  module XTrace
    class << self
      ##
      #  TraceView::XTrace.valid?
      #
      #  Perform basic validation on a potential X-Trace ID
      #
      def valid?(xtrace)
        # Shouldn't be nil
        return false unless xtrace

        # The X-Trace ID shouldn't be an initialized empty ID
        return false if (xtrace =~ /^1b0000000/i) == 0

        # Valid X-Trace IDs have a length of 58 bytes and start with '1b'
        return false unless xtrace.length == 58 && (xtrace =~ /^1b/i) == 0

        true
      rescue StandardError => e
        TraceView.logger.debug e.message
        TraceView.logger.debug e.backtrace
        false
      end

      ##
      # TraceView::XTrace.task_id
      #
      # Extract and return the task_id portion of an X-Trace ID
      #
      def task_id(xtrace)
        return nil unless TraceView::XTrace.valid?(xtrace)

        xtrace[2..41]
      rescue StandardError => e
        TraceView.logger.debug e.message
        TraceView.logger.debug e.backtrace
        return nil
      end

      ##
      # TraceView::XTrace.edge_id
      #
      # Extract and return the edge_id portion of an X-Trace ID
      #
      def edge_id(xtrace)
        return nil unless TraceView::XTrace.valid?(xtrace)

        xtrace[42..57]
      rescue StandardError => e
        TraceView.logger.debug e.message
        TraceView.logger.debug e.backtrace
        return nil
      end

      ##
      # continue_service_context
      #
      # In the case of service calls such as external HTTP requests, we
      # pass along X-Trace headers so that request context can be maintained
      # across servers and applications.
      #
      # Remote requests can return a X-Trace header in which case we want
      # to pickup on and continue the context in most cases.
      #
      # @start is the context just before the outgoing request
      #
      # @finish is the context returned to us (as an HTTP response header
      # if that be the case)
      #
      def continue_service_context(start, finish)
        if TraceView::XTrace.valid?(finish) && TraceView.tracing?

          # Assure that we received back a valid X-Trace with the same task_id
          if TraceView::XTrace.task_id(start) == TraceView::XTrace.task_id(finish)
            TraceView::Context.fromString(finish)
          else
            TraceView.logger.debug "Mismatched returned X-Trace ID: #{finish}"
          end
        end
      end
    end
  end
end
