# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  ##
  # Methods to act on, manipulate or investigate an X-Trace
  # value
  #
  # TODO add unit tests
  class XTrace
    class << self
      ##
      #  AppOpticsAPM::XTrace.valid?
      #
      #  Perform basic validation on a potential X-Trace Id
      #  returns true if it is from a valid context
      #
      def valid?(xtrace)
        # Shouldn't be nil
        return false unless xtrace

        # The X-Trace ID shouldn't be an initialized empty ID
        return false if (xtrace =~ /^2b0000000/i) == 0

        # Valid X-Trace IDs have a length of 60 bytes and start with '2b'
        xtrace.length == 60 && (xtrace =~ /^2b/i) == 0
      rescue StandardError => e
        AppOpticsAPM.logger.debug "[appoptics_apm/xtrace] #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace
        false
      end

      def sampled?(xtrace)
        valid?(xtrace) && xtrace[59].to_i & 1 == 1
      end

      def ok?(xtrace)
        # Valid X-Trace IDs have a length of 60 bytes and start with '2b'
        xtrace && xtrace.length == 60 && (xtrace =~ /^2b/i) == 0
      rescue StandardError => e
        AppOpticsAPM.logger.debug "[appoptics_apm/xtrace] #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace
        false
      end

      def set_sampled(xtrace)
        xtrace[59] = (xtrace[59].hex | 1).to_s(16).upcase
        xtrace
      end

      def unset_sampled(xtrace)
        xtrace[59] = (~(~xtrace[59].hex | 1)).to_s(16).upcase
        xtrace
      end

      ##
      # AppOpticsAPM::XTrace.task_id
      #
      # Extract and return the task_id portion of an X-Trace ID
      #
      def task_id(xtrace)
        return nil unless ok?(xtrace)

        xtrace[2..41]
      rescue StandardError => e
        AppOpticsAPM.logger.debug "[appoptics_apm/xtrace] #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace
        return nil
      end

      ##
      # AppOpticsAPM::XTrace.edge_id
      #
      # Extract and return the edge_id portion of an X-Trace ID
      #
      def edge_id(xtrace)
        return nil unless AppOpticsAPM::XTrace.valid?(xtrace)

        xtrace[42..57]
      rescue StandardError => e
        AppOpticsAPM.logger.debug "[appoptics_apm/xtrace] #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace
        return nil
      end

      ##
      # AppOpticsAPM::XTrace.edge_id_flags
      #
      # Extract and return the edge_id and flags of an X-Trace ID
      #
      def edge_id_flags(xtrace)
        return nil unless AppOpticsAPM::XTrace.valid?(xtrace)

        xtrace[42..-1]
      rescue StandardError => e
        AppOpticsAPM.logger.debug "[appoptics_apm/xtrace] #{e.message}"
        AppOpticsAPM.logger.debug e.backtrace
        return nil
      end

      def replace_edge_id(xtrace, edge_id)
        return xtrace unless edge_id.is_a? String
        "#{xtrace[0..41]}#{edge_id.upcase}#{xtrace[-2..-1]}"
      end

    end
  end
end
