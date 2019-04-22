#--
# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    module CurrentTrace

      # Creates an instance of {TraceId} with instance methods {TraceId#id} and {TraceId#for_log}.
      #
      # === Example:
      #
      #   trace = AppOpticsAPM::SDK.current_trace.new
      #   trace.id             # '7435A9FE510AE4533414D425DADF4E180D2B4E36-0'
      #   trace.for_log        # 'ao.traceId=7435A9FE510AE4533414D425DADF4E180D2B4E36-0' or '' depends on Config
      #   trace.hash_for_log   # { ao: { traceId: '7435A9FE510AE4533414D425DADF4E180D2B4E36-0 } }  or {} depends on Config
      #
      def current_trace
        TraceId.new
      end

      # @attr id the current traceId, it looks like: '7435A9FE510AE4533414D425DADF4E180D2B4E36-0'
      #          and ends in '-1' if the request is sampled and '-0' otherwise.
      #          Results in '0000000000000000000000000000000000000000-0'
      #          if the CurrentTrace instance was created outside of the context
      #          of a request.
      class TraceId
        attr_reader :id

        def initialize
          if AppOpticsAPM::Config[:log_traceId] == :never
            @id = '0000000000000000000000000000000000000000-0'
          else
            @xtrace = AppOpticsAPM::Context.toString
            task_id = AppOpticsAPM::XTrace.task_id(@xtrace)
            sampled = AppOpticsAPM::XTrace.sampled?(@xtrace)
            @id = "#{task_id}-#{sampled ? 1 : 0}"
          end
        end

        # for_log returns a string in the format 'traceId=<current_trace.id>' or ''.
        #          An empty string is returned depending on the setting for
        #          <tt>AppOpticsAPM::Config[:log_traceId]</tt>, which can be :never,
        #          :sampled, :traced, or :always.
        #
        def for_log
          @for_log ||= log? ? "ao.traceId=#{@id}" : ''
        end

        def hash_for_log
          @hash_for_log||= log? ? { ao: { traceId: @id }} : {}
        end

        def log? # should the traceId be added to the log?
          case AppOpticsAPM::Config[:log_traceId]
          when :never, nil
            false
          when :always
            AppOpticsAPM::XTrace.ok?(@xtrace)
          when :traced
            AppOpticsAPM::XTrace.valid?(@xtrace)
          when :sampled
            AppOpticsAPM::XTrace.sampled?(@xtrace)
          end
        end
      end

    end

    extend CurrentTrace
  end
end