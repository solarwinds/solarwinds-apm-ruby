# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM

  # test coverage through instrumentation_mocked and inst tests
  module TraceState
    class << self

      # prepends our kv to tracestate string
      # value has to be in W3C format
      def add_sw_member(tracestate, value)
        return tracestate unless sw_value_valid?(value)

        result = "#{APPOPTICS_TRACESTATE_ID}=#{value}#{remove_sw(tracestate)}"

        if result.bytesize > APPOPTICS_MAX_TRACESTATE_BYTES
          return reduce_size(result)
        end

        result
      end

      # extract the 'sw' tracestate member, parent_id/edge, and flags
      def sw_member_value(tracestate)
        regex = /^.*(#{APPOPTICS_TRACESTATE_ID}=(?<sw_member_value>[a-f0-9]{16}-[a-f0-9]{2})).*$/.freeze

        matches = regex.match(tracestate)

        return nil unless matches

        matches[:sw_member_value]
      end

      private

      # returns tracestate with leading comma for specific use
      # in add_sw_member
      def remove_sw(tracestate)
        return "" unless tracestate
        tracestate.gsub!(/,{0,1}\s*#{APPOPTICS_TRACESTATE_ID}=[^,]*/, '')
        (tracestate.size > 0 && tracestate[0] != ',') ? ",#{tracestate}" : tracestate
      end

      # this validates the format of the value of our vendor entry
      def sw_value_valid?(value)
        value =~ /^[a-f0-9]{16}-0[01]$/.freeze
      end

      def reduce_size(tracestate)
        size = tracestate.bytesize
        members = tracestate.split(',').reverse

        large_members = members.select { |m| m.bytesize > APPOPTICS_MAX_TRACESTATE_MEMBER_BYTES }
        while large_members[0] && size > APPOPTICS_MAX_TRACESTATE_BYTES
          size -= large_members[0].bytesize + 1 # add 1 for comma
          members.delete(large_members.shift)
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
