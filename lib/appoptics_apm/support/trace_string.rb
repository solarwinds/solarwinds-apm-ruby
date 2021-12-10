# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module TraceString
    # This module processes and queries strings of the format defined in
    # https://www.w3.org/TR/trace-context/#traceparent-header

    # Regexp copied from Ruby OT trace_string.rb
    REGEXP = /^(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2})$/.freeze
    private_constant :REGEXP

    class << self

      def split(tracestring)
        matches = REGEXP.match(tracestring)

        matches
      end

      # un-initialized (all 0 trace-id) tracestrings are not valid
      def valid?(tracestring)
        matches = REGEXP.match(tracestring)

        matches && matches[:trace_id] != ("0" * 32)
      end

      def sampled?(tracestring)
        matches = REGEXP.match(tracestring)

        matches && matches[:flags][-1].to_i & 1 == 1
      end

      def trace_id(tracestring)
        matches = REGEXP.match(tracestring)

        matches && matches[:trace_id]
      end

      def span_id(tracestring)
        matches = REGEXP.match(tracestring)

        matches && matches[:span_id]
      end

      # Extract and return the span_id and flags of an X-Trace ID
      def span_id_flags(tracestring)
        matches = REGEXP.match(tracestring)

        matches && "#{matches[:span_id]}-#{matches[:flags]}"
      end

      def set_sampled(tracestring)
        return unless tracestring

        last = tracestring[-2..-1].hex | 0x00000001
        last = last.to_s(16).rjust(2, '0')

        tracestring[-2..-1] = last
      end

      def unset_sampled(tracestring)
        return unless tracestring

        # shift left and right to set last bit to zero
        last = tracestring[-2..-1].hex >> 1 << 1
        last = last.to_s(16).rjust(2, '0')

        tracestring[-2..-1] = last
      end

      # !!! garbage in garbage out !!!
      # method is only used in TraceContext, where span_id_flags get checked
      def replace_span_id_flags(tracestring, span_id_flags)
        matches = REGEXP.match(tracestring)

        "#{matches[:version]}-#{matches[:trace_id]}-#{span_id_flags}"
      end

    end
  end
end
