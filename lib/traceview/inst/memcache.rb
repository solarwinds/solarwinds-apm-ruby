# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module MemCache
      include TraceView::API::Memcache

      def self.included(cls)
        TraceView.logger.info '[traceview/loading] Instrumenting memcache' if TraceView::Config[:verbose]

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|

            define_method("#{m}_with_traceview") do |*args|
              report_kvs = { :KVOp => m }
              report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcache][:collect_backtraces]

              if TraceView.tracing?
                TraceView::API.trace('memcache', report_kvs) do
                  send("#{m}_without_traceview", *args)
                end
              else
                send("#{m}_without_traceview", *args)
              end
            end

            class_eval "alias #{m}_without_traceview #{m}"
            class_eval "alias #{m} #{m}_with_traceview"
          end
        end

        [:request_setup, :cache_get, :get_multi].each do |m|
          if ::MemCache.method_defined? :request_setup
            cls.class_eval "alias #{m}_without_traceview #{m}"
            cls.class_eval "alias #{m} #{m}_with_traceview"
          elsif TraceView::Config[:verbose]
            TraceView.logger.warn "[traceview/loading] Couldn't properly instrument Memcache: #{m}"
          end
        end
      end

      def get_multi_with_traceview(*args)
        return get_multi_without_traceview(args) unless TraceView.tracing?

        info_kvs = {}

        begin
          info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcache][:collect_backtraces]

          if args.last.is_a?(Hash) || args.last.nil?
            info_kvs[:KVKeyCount] = args.flatten.length - 1
          else
            info_kvs[:KVKeyCount] = args.flatten.length
          end
        rescue StandardError => e
          TraceView.logger.debug "[traceview/debug] Error collecting info keys: #{e.message}"
          TraceView.logger.debug e.backtrace
        end

        TraceView::API.trace('memcache', { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_traceview(args)

          info_kvs[:KVHitCount] = values.length
          TraceView::API.log('memcache', 'info', info_kvs)

          values
        end
      end

      def request_setup_with_traceview(*args)
        if TraceView.tracing? && !TraceView.tracing_layer_op?(:get_multi)
          server, cache_key = request_setup_without_traceview(*args)

          info_kvs = { :KVKey => cache_key, :RemoteHost => server.host }
          info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcache][:collect_backtraces]
          TraceView::API.log('memcache', 'info', info_kvs)

          [server, cache_key]
        else
          request_setup_without_traceview(*args)
        end
      end

      def cache_get_with_traceview(server, cache_key)
        result = cache_get_without_traceview(server, cache_key)

        info_kvs = { :KVHit => memcache_hit?(result) }
        info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:memcache][:collect_backtraces]
        TraceView::API.log('memcache', 'info', info_kvs)

        result
      end
    end # module MemCache
  end # module Inst
end # module TraceView

if defined?(::MemCache) && TraceView::Config[:memcache][:enabled]
  ::MemCache.class_eval do
    include TraceView::Inst::MemCache
  end
end
