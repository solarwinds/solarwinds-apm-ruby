# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module API
    module Util
      BACKTRACE_CUTOFF = 100

      # Returns false is the key passed in is reserved for use by the
      # Tracelytics data-proessing pipeline. Some of these keys may not be
      # explicitly added in code, but are included by lower-level API calls
      # (i.e., liboboe).
      def valid_key?(k)
        not ['Label', 'Layer', 'Edge', 'Timestamp', 'Timestamp_u'].include? k.to_s
      end

      # Returns the current backtrace, ignoring the secified number of frames
      # at the bottom of the backtrace, and dropping all frames
      # BACKTRACE_CUTOFF beyond the last valid frame.
      def backtrace(ignore=1)
        frames = Kernel.caller
        frames_len = Kernel.caller.size
        if frames_len - ignore > BACKTRACE_CUTOFF
          frames[ignore, BACKTRACE_CUTOFF + ignore].unshift("...")
        else
          frames.drop(ignore)
        end.join("\r\n")
      end
    end
  end
end
