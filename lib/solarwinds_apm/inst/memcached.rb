# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module Memcached
      include SolarWindsAPM::API::Memcache

      def self.included(cls)
        SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting memcached' if SolarWindsAPM::Config[:verbose]

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_sw_apm") do |*args|
              kvs = { :KVOp => m }

              if args.length && !args[0].is_a?(Array)
                kvs[:KVKey] = args[0].to_s
                rhost = remote_host(args[0].to_s)
                kvs[:RemoteHost] = rhost if rhost
              end

              SolarWindsAPM::SDK.trace(:memcache, kvs: kvs) do
                result = send("#{m}_without_sw_apm", *args)

                kvs[:KVHit] = memcache_hit?(result) if m == :get && args.length && args[0].class == String
                kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:memcached][:collect_backtraces]

                result
              end
            end

            class_eval "alias #{m}_without_sw_apm #{m}"
            class_eval "alias #{m} #{m}_with_sw_apm"
          end
        end
      end

    end # module Memcached

    module MemcachedRails
      def self.included(cls)
        cls.class_eval do
          if ::Memcached::Rails.method_defined? :get_multi
            alias get_multi_without_sw_apm get_multi
            alias get_multi get_multi_with_sw_apm
          elsif SolarWindsAPM::Config[:verbose]
            SolarWindsAPM.logger.warn '[solarwinds_apm/loading] Couldn\'t properly instrument Memcached.  Partial traces may occur.'
          end
        end
      end

      def get_multi_with_sw_apm(keys, raw = false)
        if SolarWindsAPM.tracing?
          layer_kvs = {}
          layer_kvs[:KVOp] = :get_multi

          SolarWindsAPM::SDK.trace(:memcache, kvs: layer_kvs, protect_op: :get_multi) do
            layer_kvs[:KVKeyCount] = keys.flatten.length

            values = get_multi_without_sw_apm(keys, raw)

            layer_kvs[:KVHitCount] = values.length
            layer_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:memcached][:collect_backtraces]

            values
          end
        else
          get_multi_without_sw_apm(keys, raw)
        end
      end
    end # module MemcachedRails
  end # module Inst
end # module SolarWindsAPM

if defined?(Memcached) && SolarWindsAPM::Config[:memcached][:enabled]
  Memcached.class_eval do
    include SolarWindsAPM::Inst::Memcached
  end

  if defined?(Memcached::Rails)
    Memcached::Rails.class_eval do
      include SolarWindsAPM::Inst::MemcachedRails
    end
  end
end
