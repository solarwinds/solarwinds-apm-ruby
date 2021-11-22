#--
# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    module CurrentTrace
      # TODO - further refactoring needed for w3c log injection

      # Creates an instance of {TraceId} with instance methods {TraceId#id}, {TraceId#for_log}
      # and {TraceId#hash_for_log}.
      #
      # === Example:
      #
      #   trace = AppOpticsAPM::SDK.current_trace
      #   trace.id             # '7435a9fe510ae4533414d425dadf4e36-0'
      #   trace.for_log        # 'ao.traceId=7435a9fe510ae4533414d425dadf4e36-0' or '' depends on Config
      #   trace.hash_for_log   # { ao: { traceId: '7435a9fe510ae4533414d425dadf4e36-0 } }  or {} depends on Config
      #
      # Configure traceId injection with lograge:
      #
      #    Lograge.custom_options = lambda do |event|
      #       AppOpticsAPM::SDK.current_trace.hash_for_log
      #    end
      #
      def current_trace
        TraceId.new
      end

      # @attr id the current traceId, it looks like: '7435a9fe510ae4533414d425dadf4e36-0'
      #          and ends in '-1' if the request is sampled and '-0' otherwise.
      #          Results in '00000000000000000000000000000000-0'
      #          if the CurrentTrace instance was created outside of the context
      #          of a request.
      class TraceId
        attr_reader :id

        def initialize
          @tracestring = AppOpticsAPM::Context.toString
          trace_id = AppOpticsAPM::TraceString.trace_id(@tracestring)
          sampled = AppOpticsAPM::TraceString.sampled?(@tracestring)
          @id = "#{trace_id}-#{sampled ? 1 : 0}"
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
          @hash_for_log ||= log? ? { ao: { traceId: @id } } : {}
        end

        def log? # should the traceId be added to the log?
          case AppOpticsAPM::Config[:log_traceId]
          when :never, nil
            false
          when :always
            AppOpticsAPM::TraceString.ok?(@tracestring)
          when :traced
            AppOpticsAPM::TraceString.valid?(@tracestring)
          when :sampled
            AppOpticsAPM::TraceString.sampled?(@tracestring)
          end
        end
      end

    end

    extend CurrentTrace
  end
end
