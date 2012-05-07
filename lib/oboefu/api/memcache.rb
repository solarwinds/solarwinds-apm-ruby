# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
#
module Oboe
  module API
    module Memcache
      MEMCACHE_OPS = %w{add append cas decr decrement delete fetch get get_multi incr increment prepend replace set}

      def memcache_hit?(result)
        (not result.nil? and 1) or 0
      end

      def remote_host(key)
        return unless defined?(Lib.memcached_server_by_key)\
          and defined?(@struct) and defined?(is_unix_socket?)

        server_as_array = Lib.memcached_server_by_key(@struct, args[0].to_s)
        if server_as_array.is_a?(Array)
            server = server_as_array.first
            if is_unix_socket?(server)
                return "localhost"
            elsif defined?(server.hostname)
                return server.hostname
            end
        end
      end
    end
  end
end
