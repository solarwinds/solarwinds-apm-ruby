# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.
#

if defined?(Memcached) and Oboe::Config[:memcached][:enabled]
  class Memcached
    include Oboe::API::Memcache

    MEMCACHE_OPS.reject { |m| not method_defined?(m) }.each do |m|
      define_method("#{m}_with_oboe") do |*args|
        opts = { :KVOp => m }
        if args.length and args[0].class != Array
            opts[:KVKey] = args[0].to_s
            rhost = remote_host(args[0].to_s)
            opts[:RemoteHost] = rhost if rhost
        end

        Oboe::API.trace('memcache', opts) do
          result = send("#{m}_without_oboe", *args)
          if m == :get and args.length and args[0].class == String
              Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
          end
          result
        end
      end

      class_eval "alias #{m}_without_oboe #{m}"
      class_eval "alias #{m} #{m}_with_oboe"
    end
  end
  puts "[oboe/loading] Instrumenting memcached" if Oboe::Config[:verbose]
end
