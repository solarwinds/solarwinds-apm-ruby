# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  module Inst
    module Dalli
      include TraceView::API::Memcache

      def self.included(cls)
        cls.class_eval do
          TraceView.logger.info '[traceview/loading] Instrumenting memcache (dalli)' if TraceView::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_traceview perform
            alias perform perform_with_traceview
          else TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument Memcache (Dalli).  Partial traces may occur.'
          end

          if ::Dalli::Client.method_defined? :get_multi
            alias get_multi_without_traceview get_multi
            alias get_multi get_multi_with_traceview
          end
        end
      end

      def perform_with_traceview(*all_args, &blk)
        op, key, *args = *all_args

        report_kvs = {}
        report_kvs[:KVOp] = op
        report_kvs[:KVKey] = key
        if @servers.is_a?(Array) && !@servers.empty?
          report_kvs[:RemoteHost] = @servers.join(", ")
        end

        if TraceView.tracing? && !TraceView.tracing_layer_op?(:get_multi)
          TraceView::API.trace(:memcache, report_kvs) do
            result = perform_without_traceview(*all_args, &blk)

            # Clear the hash for a potential info event
            report_kvs.clear
            report_kvs[:KVHit] = memcache_hit?(result) if op == :get && key.class == String
            report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:dalli][:collect_backtraces]

            TraceView::API.log(:memcache, :info, report_kvs) unless report_kvs.empty?
            result
          end
        else
          perform_without_traceview(*all_args, &blk)
        end
      end

      def get_multi_with_traceview(*keys)
        return get_multi_without_traceview(*keys) unless TraceView.tracing?

        info_kvs = {}

        begin
          info_kvs[:KVKeyCount] = keys.flatten.length
          info_kvs[:KVKeyCount] = (info_kvs[:KVKeyCount] - 1) if keys.last.is_a?(Hash) || keys.last.nil?
          if @servers.is_a?(Array) && !@servers.empty?
            info_kvs[:RemoteHost] = @servers.join(", ")
          end
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        TraceView::API.trace(:memcache, { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_traceview(*keys)

          info_kvs[:KVHitCount] = values.length
          info_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:dalli][:collect_backtraces]
          TraceView::API.log(:memcache, :info, info_kvs)

          values
        end
      end
    end
  end
end

if defined?(Dalli) && TraceView::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include TraceView::Inst::Dalli
  end
end
