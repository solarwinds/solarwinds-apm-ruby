# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module TraceParent
    # Regexp copied from Ruby OT trace_parent.rb
    REGEXP = /^(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2})$/.freeze
    # REGEXP = /^(?<version>[A-Fa-f0-9]{2})(?<trace_id>[A-Fa-f0-9]{40})(?<parent_id>[A-Fa-f0-9]{16})(?<flags>[A-Fa-f0-9]{2})?$/.freeze

    class << self
      def valid?(traceparent)
        matches = REGEXP.match(traceparent)

        matches && matches.length == 5 && !matches.to_a.include?(nil)
      end

      def extract_id(traceparent)
        matches = REGEXP.match(traceparent)

        return nil unless matches && matches.length == 5 && !matches.to_a.include?(nil)

        matches[:trace_id]
      end

      def sampled?(traceparent)
        valid?(traceparent) && traceparent[-1..-1].to_i & 1 == 1
      end

      # Extract and return the edge_id and flags of an X-Trace ID
      def edge_id_flags(traceparent)
        return nil unless valid?(traceparent)

        traceparent[-19..-1]
      end

      def task_id(traceparent)
        return nil unless valid?(traceparent)

        traceparent[3..34]
      end

    end
  end
end
