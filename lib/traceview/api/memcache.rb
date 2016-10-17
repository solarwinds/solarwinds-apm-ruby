# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module API
    ##
    # Utility methods for the Memcache instrumentation
    module Memcache
      MEMCACHE_OPS = %w(add append cas decr decrement delete fetch get incr increment prepend replace set)

      def memcache_hit?(result)
        result.nil? ? 0 : 1
      end

      def remote_host(key)
        return unless defined?(Lib.memcached_server_by_key) &&
                      defined?(@struct) && defined?(is_unix_socket?)

        server_as_array = Lib.memcached_server_by_key(@struct, key.to_s)

        return unless server_as_array.is_a?(Array)

        server = server_as_array.first
        if is_unix_socket?(server)
          'localhost'
        elsif defined?(server.hostname)
          server.hostname
        end
      end
    end
  end
end
