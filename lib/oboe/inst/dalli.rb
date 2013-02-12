# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Dalli
      include Oboe::API::Memcache

      def self.included(cls)
        cls.class_eval do
          puts "[oboe/loading] Instrumenting memcache (dalli)" if Oboe::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_oboe perform
            alias perform perform_with_oboe
          else puts "[oboe/loading] Couldn't properly instrument Memcache (Dalli).  Partial traces may occur."
          end

          if ::Dalli::Client.method_defined? :get_multi
            alias get_multi_without_oboe get_multi
            alias get_multi get_multi_with_oboe
          end
        end
      end

      def perform_with_oboe(op, key, *args)
        if Oboe.tracing? and not Oboe::Context.tracing_layer_op?(:get_multi)
          opts = {}
          opts[:KVOp] = op
          opts[:KVKey] = key 

          Oboe::API.trace('memcache', opts || {}) do
            result = perform_without_oboe(op, key, *args)
            if op == :get and key.class == String
                Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
            end
            result
          end
        else
          perform_without_oboe(op, key, *args)
        end
      end

      def get_multi_with_oboe(*keys)
        if Oboe::Config.tracing?
          layer_kvs = {}
          layer_kvs[:KVOp] = :get_multi

          Oboe::API.trace('memcache', layer_kvs || {}, :get_multi) do
            begin
              info_kvs = {}
               
              if keys.last.is_a?(Hash) || keys.last.nil?
                info_kvs[:KVKeyCount] = keys.flatten.length - 1
              else
                info_kvs[:KVKeyCount] = keys.flatten.length 
              end

              values = get_multi_without_oboe(keys)
              
              info_kvs[:KVHitCount] = values.length
              Oboe::API.log('memcache', 'info', info_kvs)
            rescue
              values = get_multi_without_oboe(keys)
            end
            values 
          end
        else
          get_multi_without_oboe(keys)
        end
      end
    end
  end
end

if defined?(Dalli) and Oboe::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include Oboe::Inst::Dalli
  end
end
