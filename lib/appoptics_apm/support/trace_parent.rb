# Copyright (c) SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module TraceParent
    # TODO NH-2303 currently we are using the "old" x-trace format
    #  switch once we process w3c format
    # Regexp copied from Ruby OT trace_parent.rb
    # REGEXP = /^(?<version>[A-Fa-f0-9]{2})-(?<trace_id>[A-Fa-f0-9]{32})-(?<span_id>[A-Fa-f0-9]{16})-(?<flags>[A-Fa-f0-9]{2})(?<ignored>-.*)?$/.freeze
    REGEXP = /^(?<version>[A-Fa-f0-9]{2})(?<trace_id>[A-Fa-f0-9]{40})(?<parent_id>[A-Fa-f0-9]{16})(?<flags>[A-Fa-f0-9]{2})?$/.freeze

    class << self
      def valid?(traceparent)
        matches = REGEXP.match(traceparent)

        return false if !matches || matches.length < 5 || matches.to_a.include?(nil)

        true
      end

      def extract_id(traceparent)
        matches = REGEXP.match(traceparent)

        return nil if !matches || matches.length < 5 || matches.to_a.include?(nil)

        matches[:trace_id]
      end

    end
  end
end
