# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  # test coverage through instrumentation_mocked and inst tests
  module TraceState
    class << self

      # prepends our kv to tracestate string
      # value has to be in W3C format
      def add_kv(tracestate, value)
        return tracestate unless sw_value_valid?(value)

        result = "#{APPOPTICS_TRACESTATE_ID}=#{value}#{remove_sw(tracestate)}"

        if result.bytesize > APPOPTICS_MAX_TRACESTATE_BYTES
          return reduce_size(result)
        end

        result
      end

     # extract the 'sw' tracestate member
      def sw_tracestate(tracestate)
        regex = /^.*(sw=(?<sw_tracestate>(?<parent_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))).*$/.freeze

        matches = regex.match(tracestate)
        return nil, nil, nil unless matches
        [matches[:sw_tracestate], matches[:parent_id], (matches[:flags][1].to_i & 1) == 1]
      end

      private

      def remove_sw(tracestate)
        return "" unless tracestate
        tracestate.gsub!(/,{0,1}\s*sw=[^,]*/, '')
        (tracestate.size > 0 && tracestate[0] != ',') ? ",#{tracestate}" : tracestate
      end

      # this validates the format of the value of our vendor entry
      def sw_value_valid?(value)
        value =~ /^[a-f0-9]{16}-0[01]$/.freeze
      end

      def reduce_size(tracestate)
        members = tracestate.split(',').reverse
        while members != members.delete_if { |m| m.bytesize > 128 }
        end

        tracestate = members.reverse.join(',')

        until tracestate.bytesize <= APPOPTICS_MAX_TRACESTATE_BYTES do
          tracestate.gsub!(/,[^,]*$/, '')
        end
        tracestate
      end

    end
  end
end
