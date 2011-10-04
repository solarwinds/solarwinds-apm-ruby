if defined?(MemCache)
  class MemCache
    [:decr, :get, :fetch, :get_multi, :incr, :set, :cas, :add, :replace, :prepend, :append, :delete].each do |m|
      next unless method_defined?(m)

      class_eval("alias clean_#{m} #{m}")
      opts = { :KVOp => m }
      define_method(m) do |*args|
        Oboe::Inst.trace_layer_block('memcache', opts) do
          send("clean_#{m}", *args) 
        end
      end
    end

    alias clean_request_setup request_setup
    define_method(:request_setup) do |*args|
      server, cache_key = clean_request_setup(*args)
      Oboe::Inst.log('memcache', 'info', { :KVKey => cache_key, :RemoteHost => server.host })
      return [server, cache_key]
    end

    alias clean_cache_get cache_get
    define_method(:cache_get) do |server, cache_key|
      result = clean_cache_get(server, cache_key)
      Oboe::Inst.log('memcache', 'info', { :KVHit => (!result.nil? && 1) || 0 })
      result
    end
  end
end
