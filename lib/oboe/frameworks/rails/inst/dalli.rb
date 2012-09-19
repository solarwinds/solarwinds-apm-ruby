# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Dalli
      include Oboe::API::Memcache

      def self.included(cls)
        cls.class_eval do
          puts "[oboe/loading] Instrumenting Memcache (Dalli)" if Oboe::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_oboe perform
            alias perform perform_with_oboe
          else puts "[oboe/loading] Couldn't properly instrument Memcache (Dalli).  Partial traces may occur."
          end
        end
      end

      def perform_with_oboe(op, key, *args)
        if Oboe::Config.tracing?
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
    end
  end
end

if defined?(Dalli)
  Dalli::Client.module_eval do
    include Oboe::Inst::Dalli
  end
end
