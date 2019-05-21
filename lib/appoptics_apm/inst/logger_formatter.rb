# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module AppOpticsAPM
  module Logger
    module Formatter

      def call(severity, time, progname, msg)
        return super if AppOpticsAPM::Config[:log_traceId] == :never

        msg = insert_trace_id(msg)
        super
      end

      private

      def insert_trace_id(msg)
        return msg if msg =~ /ao(=>{:|\.){1}traceId/

        current_trace = AppOpticsAPM::SDK.current_trace
        if current_trace.log?
          case msg
          when ::String
            msg = msg.strip.empty? ? msg : insert_before_empty_lines(msg, current_trace.for_log)
          when ::Exception
            # conversion to String copied from Logger::Formatter private method #msg2str
            msg = ("#{msg.message} (#{msg.class}) #{current_trace.for_log}\n" <<
              (msg.backtrace || []).join("\n"))
          end
        end
        msg
      end

      def insert_before_empty_lines(msg, for_log)
        stripped = msg.rstrip
        "#{stripped} #{for_log}#{msg[stripped.length..-1]}"
      end
    end
  end
end

if AppOpticsAPM.loaded
  class Logger
    class Formatter
      prepend AppOpticsAPM::Logger::Formatter
    end
  end
end
