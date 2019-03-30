#--
# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.
#++

module AppOpticsAPM
  module SDK

    module CurrentTrace
      def current_trace
        Trace.new
      end

      class Trace
        attr_reader :id

        def initialize
          @xtrace = AppOpticsAPM::Context.toString
          task_id = AppOpticsAPM::XTrace.task_id(@xtrace)
          sampled = AppOpticsAPM::XTrace.sampled?(@xtrace)
          @id = "#{task_id}-#{sampled ? 1 : 0}"
        end

        def for_log
          return '' unless AppOpticsAPM::XTrace.valid?(@xtrace)
          "traceId=#{@id}"
        end
      end
    end

    extend CurrentTrace
  end
end