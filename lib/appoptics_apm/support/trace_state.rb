# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module TraceState
    class << self

      def add_parent_id(trace_state, parent_id)
        h = to_hash(trace_state)

        if id_valid?(parent_id)
          result = { APPOPTICS_TRACE_STATE_ID => parent_id }
          result = result.merge(h) { |_k, v1, _v2| v1 }
        else
          result = h
        end
        # max number of members in tracestate is 32
        result.map { |k,v| "#{k}=#{v}" }[0..31].join(",")
      end

      def extract_id(trace_state)
        h = to_hash(trace_state)

        h[APPOPTICS_TRACE_STATE_ID]
      end

      private

      def to_hash(trace_state)
        return {} unless trace_state
        h = {}
        trace_state.split(/\s*,\s*/).each do |member|
          next if member.empty? || !valid_member?(member)
          a = member.strip.split('=')
          if a.length == 2
            # using ||= to make sure we keep the first occurrence
            # if there are duplicates
            h[a[0].strip] ||= a[1]
          end
        end
        h
      end

      def valid_member?(member)
        vendor = /[a-z][a-z0-9*\/_-]{0,255}/
        tenant_vendor = /[a-z0-9][a-z0-9*\/_-]{0,240}@[a-z][a-z0-9*\/_-]{0,13}/
        value = /[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x21-\x2B\x2D-\x3C\x3E-\x7E]/
        member =~ /(^#{tenant_vendor})|(^#{vendor})\s*=\s*#{value}$/
      end

      def id_valid?(parent_id)
        parent_id =~ /^[A-Fa-f0-9]{16}0[01]$/
        # TODO NH-2303 once we include dashes use the following
        # parent_id =~ /^[A-Fa-f0-9]{16}-0[01]$/
      end

      # this method is only used in tests
      def valid?(trace_state)
        vendor = /[a-z][a-z0-9*\/_-]{0,255}/
        tenant_vendor = /[a-z0-9][a-z0-9*\/_-]{0,240}@[a-z][a-z0-9*\/_-]{0,13}/
        value = /[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x21-\x2B\x2D-\x3C\x3E-\x7E]/
        member = /(#{tenant_vendor})|(#{vendor})\s*=\s*#{value}/
        trace_state.strip =~ /^(#{member}\s*,\s*)*#{member}$/
      end

    end
  end
end