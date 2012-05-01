module Oboe
  module API
    module Util

      # Returns false is the key passed in is reserved for use by the
      # Tracelytics data-proessing pipeline. Some of these keys may not be
      # explicitly added in code, but are included by lower-level API calls
      # (i.e., liboboe).
      def valid_key?(k)
        not ['Label', 'Layer', 'Edge', 'Timestamp', 'Timestamp_u'].include? k.to_s
      end
    end
  end
end
