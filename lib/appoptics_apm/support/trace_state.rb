# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  # test coverage through instrumentation_mocked and inst tests
  module TraceState
    class << self

      # prepends our kv to trace_state string
      # value has to be in W3C format
      def add_kv(trace_state, value)
        h = to_hash(trace_state)

        if value_valid?(value)
          result = { APPOPTICS_TRACE_STATE_ID => value }
          result = result.merge(h) { |_k, v1, _v2| v1 }
        else
          result = h
        end

        # max number of members in tracestate is 32
        result_string = result.map { |k,v| "#{k}=#{v}" }[0..31].join(",")
        if result_string.bytesize <= APPOPTICS_MAX_TRACESTATE_BYTES
          result_string
        else
          reduce_size(result)
        end
      rescue => e
        puts e
        puts AppOpticsAPM::API.backtrace
      end

      def extract_sw_value(trace_state)
        h = to_hash(trace_state)

        value = h[APPOPTICS_TRACE_STATE_ID]
        return value_valid?(value) ? value : nil
      end

      def sw_tracestate(tracestate)
        regex = /^.*(sw=(?<sw_tracestate>(?<parent_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))).*$/.freeze
        # TODO NH-2303
        #  remove this, it matches the legacy ao format
        # regex = /^.*(sw=(?<sw_tracestate>(?<parent_id>[A-F0-9]{16})(?<flags>[A-F0-9]{2}))).*$/.freeze

        matches = regex.match(tracestate)
        return nil, nil, nil unless matches
        [matches[:sw_tracestate], matches[:parent_id], (matches[:flags][1].to_i & 1) == 1]
      end

      def extract_sw_parent_id_sampled(tracestate)
        regex = /(?<parent_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2})?$/.freeze
        # TODO NH-2303
        #  remove this, it matches the legacy ao format
        # regex = /(?<parent_id>[A-F0-9]{16})(?<flags>[A-F0-9]{2})?$/.freeze
        h = to_hash(tracestate)
        value = h[APPOPTICS_TRACE_STATE_ID]
        matches = regex.match(value)
        return nil,nil if !matches || matches.length != 3 || matches.to_a.include?(nil)

        [matches[:parent_id], (matches[:flags][1].to_i & 1) == 1]
      end

      def validate_fix(trace_state)
        return nil unless trace_state && trace_state.is_a?(String)

        members = trace_state.split(/\s*,\s*/).keep_if do |member|
          valid_member?(member)
        end
        members.empty? ? nil : members.join(',')
      end

      private

      def to_hash(trace_state)
        return {} unless trace_state
        if trace_state.is_a?(String)
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
        elsif trace_state.is_a?(Array)
          # in httpclient trace_state can be an array
          Hash[*trace_state.flatten]
        end
      end

      def valid_member?(member)
        vendor = /[a-z][a-z0-9*\/_-]{0,255}/.freeze
        tenant_vendor = /[a-z0-9][a-z0-9*\/_-]{0,240}@[a-z][a-z0-9*\/_-]{0,13}/.freeze
        value = /[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x21-\x2B\x2D-\x3C\x3E-\x7E]/.freeze
        member =~ /((^#{tenant_vendor})|(^#{vendor}))\s*=\s*#{value}$/.freeze
      end

      # this validates the format of the value of our vendor entry
      def value_valid?(value)
        value =~ /^[a-f0-9]{16}-0[01]$/.freeze
      end

      def valid?(trace_state)
        vendor = /[a-z][a-z0-9*\/_-]{0,255}/
        tenant_vendor = /[a-z0-9][a-z0-9*\/_-]{0,240}@[a-z][a-z0-9*\/_-]{0,13}/
        value = /[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x21-\x2B\x2D-\x3C\x3E-\x7E]/
        member = /(#{tenant_vendor})|(#{vendor})\s*=\s*#{value}/
        trace_state.strip =~ /^(#{member}\s*,\s*)*#{member}$/
      end

      def reduce_size(result)
        result.delete_if { |k,v| "#{k}=#{v}".size > 128 }
        result_string = ""
        result.each do |k,v|
          entry = ",#{k}=#{v}"
          return result_string[1..-1] if (result_string.bytesize + entry.bytesize) > APPOPTICS_MAX_TRACESTATE_BYTES+1
          result_string << entry
        end
        result_string[1..-1]
      rescue => e
        puts e
        puts AppOpticsAPM::API.backtrace
      end

    end
  end
end