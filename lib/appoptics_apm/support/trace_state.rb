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
        result.map { |k,v| "#{k}=#{v}" }.join(",")
      end

      private

      def to_hash(trace_state)
        return {} unless valid?(trace_state)

        h = {}
        trace_state.split(',').each do |ele|
          a = ele.split('=')
          if a.length == 2
            h[a[0].strip] = a[1].strip
          else
            h = {}
            puts "oops, this should not be reached"
            break
          end
        end
        h
      end

      def valid?(trace_state)
        tenant = /([a-z0-9][a-z0-9*\/_-]{0,240}@)?/
        vendor = /[a-z0-9][a-z0-9*\/_-]{0,13}/
        value = /[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x20-\x2B\x2D-\x3C\x3E-\x7E]/
        member = /#{tenant}#{vendor}\s*=\s*#{value}/
        trace_state =~ /(#{member},)*#{member}/
      end

      def id_valid?(parent_id)
        parent_id =~ /^[A-Fa-f0-9]{16}$/
      end

    end
  end
end