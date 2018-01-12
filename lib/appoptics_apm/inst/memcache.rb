# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module MemCache
      include AppOpticsAPM::API::Memcache

      def self.included(cls)
        AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting memcache' if AppOpticsAPM::Config[:verbose]

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|

            define_method("#{m}_with_appoptics") do |*args|
              report_kvs = { :KVOp => m }
              report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:memcache][:collect_backtraces]

              if AppOpticsAPM.tracing?
                AppOpticsAPM::API.trace(:memcache, report_kvs) do
                  send("#{m}_without_appoptics", *args)
                end
              else
                send("#{m}_without_appoptics", *args)
              end
            end

            class_eval "alias #{m}_without_appoptics #{m}"
            class_eval "alias #{m} #{m}_with_appoptics"
          end
        end

        [:request_setup, :cache_get, :get_multi].each do |m|
          if ::MemCache.method_defined? :request_setup
            cls.class_eval "alias #{m}_without_appoptics #{m}"
            cls.class_eval "alias #{m} #{m}_with_appoptics"
          elsif AppOpticsAPM::Config[:verbose]
            AppOpticsAPM.logger.warn "[appoptics_apm/loading] Couldn't properly instrument Memcache: #{m}"
          end
        end
      end

      def get_multi_with_appoptics(*args)
        return get_multi_without_appoptics(args) unless AppOpticsAPM.tracing?

        info_kvs = {}

        begin
          info_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:memcache][:collect_backtraces]

          if args.last.is_a?(Hash) || args.last.nil?
            info_kvs[:KVKeyCount] = args.flatten.length - 1
          else
            info_kvs[:KVKeyCount] = args.flatten.length
          end
        rescue StandardError => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] Error collecting info keys: #{e.message}"
          AppOpticsAPM.logger.debug e.backtrace
        end

        AppOpticsAPM::API.trace(:memcache, { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_appoptics(args)

          info_kvs[:KVHitCount] = values.length
          AppOpticsAPM::API.log(:memcache, :info, info_kvs)

          values
        end
      end

      def request_setup_with_appoptics(*args)
        if AppOpticsAPM.tracing? && !AppOpticsAPM.tracing_layer_op?(:get_multi)
          server, cache_key = request_setup_without_appoptics(*args)

          info_kvs = { :KVKey => cache_key, :RemoteHost => server.host }
          info_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:memcache][:collect_backtraces]
          AppOpticsAPM::API.log(:memcache, :info, info_kvs)

          [server, cache_key]
        else
          request_setup_without_appoptics(*args)
        end
      end

      def cache_get_with_appoptics(server, cache_key)
        result = cache_get_without_appoptics(server, cache_key)

        info_kvs = { :KVHit => memcache_hit?(result) }
        info_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:memcache][:collect_backtraces]
        AppOpticsAPM::API.log(:memcache, :info, info_kvs)

        result
      end
    end # module MemCache
  end # module Inst
end # module AppOpticsAPM

if defined?(::MemCache) && AppOpticsAPM::Config[:memcache][:enabled]
  ::MemCache.class_eval do
    include AppOpticsAPM::Inst::MemCache
  end
end
