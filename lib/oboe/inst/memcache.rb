# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module MemCache
      include Oboe::API::Memcache
      
      def self.included(cls)
        Oboe.logger.info "[oboe/loading] Instrumenting memcache" if Oboe::Config[:verbose]

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| not method_defined?(m) }.each do |m|

            define_method("#{m}_with_oboe") do |*args|
              report_kvs = { :KVOp => m }

              if Oboe.tracing?
                Oboe::API.trace('memcache', report_kvs) do
                  result = send("#{m}_without_oboe", *args) 
                end
              else
                result = send("#{m}_without_oboe", *args) 
              end
              result
            end

            class_eval "alias #{m}_without_oboe #{m}"
            class_eval "alias #{m} #{m}_with_oboe"
          end

          if ::MemCache.method_defined? :request_setup
            alias request_setup_without_oboe request_setup
            alias request_setup request_setup_with_oboe
          elsif Oboe::Config[:verbose]
            Oboe.logger.warn "[oboe/loading] Couldn't properly instrument Memcache.  Partial traces may occur."
          end

          if ::MemCache.method_defined? :cache_get
            alias cache_get_without_oboe cache_get
            alias cache_get cache_get_with_oboe
          elsif Oboe::Config[:verbose]
            Oboe.logger.warn "[oboe/loading] Couldn't properly instrument Memcache.  Partial traces may occur." 
          end
          
          if ::MemCache.method_defined? :get_multi
            alias get_multi_without_oboe get_multi
            alias get_multi get_multi_with_oboe
          elsif Oboe::Config[:verbose]
            Oboe.logger.warn "[oboe/loading] Couldn't properly instrument Memcache.  Partial traces may occur." 
          end
        end
      end

      def get_multi_with_oboe(*args)
        if Oboe.tracing?
          layer_kvs = {}
          layer_kvs[:KVOp] = :get_multi

          Oboe::API.trace('memcache', layer_kvs || {}, :get_multi) do
            begin
              info_kvs = {}
               
              if args.last.is_a?(Hash) || args.last.nil?
                info_kvs[:KVKeyCount] = args.flatten.length - 1
              else
                info_kvs[:KVKeyCount] = args.flatten.length 
              end

              values = get_multi_without_oboe(args)
              
              info_kvs[:KVHitCount] = values.length
              Oboe::API.log('memcache', 'info', info_kvs)
            rescue
              values = get_multi_without_oboe(args)
            end
            values 
          end
        else
          get_multi_without_oboe(args)
        end
      end
      
      def request_setup_with_oboe(*args)
        if Oboe.tracing? and not Oboe::Context.tracing_layer_op?(:get_multi)
          server, cache_key = request_setup_without_oboe(*args)
          Oboe::API.log('memcache', 'info', { :KVKey => cache_key, :RemoteHost => server.host })
        else
          server, cache_key = request_setup_without_oboe(*args)
        end
        return [server, cache_key]
      end

      def cache_get_with_oboe(server, cache_key)
        result = cache_get_without_oboe(server, cache_key)
        Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
        result
      end

    end # module MemCache
  end # module Inst
end # module Oboe

if defined?(::MemCache) and Oboe::Config[:memcache][:enabled]
  ::MemCache.class_eval do
    include Oboe::Inst::MemCache
  end
end

