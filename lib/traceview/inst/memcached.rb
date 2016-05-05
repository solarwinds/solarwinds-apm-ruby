# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module Memcached
      include TraceView::API::Memcache

      def self.included(cls)
        TraceView.logger.info '[traceview/loading] Instrumenting memcached' if TraceView::Config[:verbose]

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_traceview") do |*args|
              opts = { :KVOp => m }

              if args.length && !args[0].is_a?(Array)
                opts[:KVKey] = args[0].to_s
                rhost = remote_host(args[0].to_s)
                opts[:RemoteHost] = rhost if rhost
              end

              TraceView::API.trace(:memcache, opts) do
                result = send("#{m}_without_traceview", *args)

                info_kvs = {}
                info_kvs[:KVHit] = memcache_hit?(result) if m == :get && args.length && args[0].class == String
                info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcached][:collect_backtraces]

                TraceView::API.log(:memcache, :info, info_kvs) unless info_kvs.empty?
                result
              end
            end

            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          end
        end
      end

    end # module Memcached

    module MemcachedRails
      def self.included(cls)
        cls.class_eval do
          if ::Memcached::Rails.method_defined? :get_multi
            alias get_multi_without_traceview get_multi
            alias get_multi get_multi_with_traceview
          elsif TraceView::Config[:verbose]
            TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument Memcached.  Partial traces may occur.'
          end
        end
      end

      def get_multi_with_traceview(keys, raw = false)
        if TraceView.tracing?
          layer_kvs = {}
          layer_kvs[:KVOp] = :get_multi

          TraceView::API.trace(:memcache, layer_kvs || {}, :get_multi) do
            begin
              info_kvs = {}
              info_kvs[:KVKeyCount] = keys.flatten.length

              values = get_multi_without_traceview(keys, raw)

              info_kvs[:KVHitCount] = values.length
              info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcached][:collect_backtraces]

              TraceView::API.log(:memcache, :info, info_kvs)
            rescue
              values = get_multi_without_traceview(keys, raw)
            end
            values
          end
        else
          get_multi_without_traceview(keys, raw)
        end
      end
    end # module MemcachedRails
  end # module Inst
end # module TraceView

if defined?(::Memcached) && TraceView::Config[:memcached][:enabled]
  ::Memcached.class_eval do
    include TraceView::Inst::Memcached
  end

  if defined?(::Memcached::Rails)
    ::Memcached::Rails.class_eval do
      include TraceView::Inst::MemcachedRails
    end
  end
end
