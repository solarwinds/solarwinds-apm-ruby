# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

if defined?(::MemCache)
  class ::MemCache
    include Oboe::API::Memcache

    MEMCACHE_OPS.reject { |m| not method_defined?(m) }.each do |m|
      opts = { :KVOp => m }
      define_method("#{m}_with_oboe") do |*args|
        Oboe::API.trace('memcache', opts) do
          send("#{m}_without_oboe", *args) 
        end
      end

      class_eval "alias #{m}_without_oboe #{m}"
      class_eval "alias #{m} #{m}_with_oboe"
    end

    define_method(:request_setup_with_oboe) do |*args|
      server, cache_key = request_setup_without_oboe(*args)
      Oboe::API.log('memcache', 'info', { :KVKey => cache_key, :RemoteHost => server.host })
      return [server, cache_key]
    end

    alias request_setup_without_oboe request_setup
    alias request_setup request_setup_with_oboe


    define_method(:cache_get_with_oboe) do |server, cache_key|
      result = cache_get_without_oboe(server, cache_key)
      Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
      result
    end

    alias cache_get_without_oboe cache_get
    alias cache_get cache_get_with_oboe
  end
  puts "[oboe_fu/loading] Instrumenting memcache" if Oboe::Config[:verbose]
end
