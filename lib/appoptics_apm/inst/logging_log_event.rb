# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

module AppOpticsAPM
  module Logging
    module LogEvent
      include AppOpticsAPM::Logger::Formatter # provides #insert_trace_id

      def initialize(logger, level, data, caller_tracing )
        return super if AppOpticsAPM::Config[:log_traceId] == :never

        data = insert_trace_id(data)
        super
      end

    end
  end
end

if AppOpticsAPM.loaded && defined?(Logging::LogEvent)
  module Logging
    class LogEvent
      prepend AppOpticsAPM::Logging::LogEvent
    end
  end
end