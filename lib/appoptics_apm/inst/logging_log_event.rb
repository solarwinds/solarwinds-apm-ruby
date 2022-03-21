# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

module SolarWindsAPM
  module Logging
    module LogEvent
      include SolarWindsAPM::Logger::Formatter # provides #insert_trace_id

      def initialize(logger, level, data, caller_tracing )
        return super if SolarWindsAPM::Config[:log_traceId] == :never

        data = insert_trace_id(data)
        super
      end

    end
  end
end

if SolarWindsAPM.loaded && defined?(Logging::LogEvent)
  Logging::LogEvent.send(:prepend, SolarWindsAPM::Logging::LogEvent)
end
