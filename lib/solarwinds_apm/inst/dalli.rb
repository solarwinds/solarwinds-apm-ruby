# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module Dalli
      include SolarWindsAPM::API::Memcache

      def self.included(cls)
        cls.class_eval do
          SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting memcache (dalli)' if SolarWindsAPM::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_sw_apm perform
            alias perform perform_with_sw_apm
          else
            SolarWindsAPM.logger.warn '[solarwinds_apm/loading] Couldn\'t properly instrument Memcache (Dalli).  Partial traces may occur.'
          end

          if ::Dalli::Client.method_defined? :get_multi
            alias get_multi_without_sw_apm get_multi
            alias get_multi get_multi_with_sw_apm
          end
        end
      end

      def perform_with_sw_apm(*all_args, &blk)
        op, key, *args = *all_args

        report_kvs = {}
        report_kvs[:KVOp] = op
        report_kvs[:KVKey] = key

        servers = @servers || @normalized_servers # name change since Dall 3.2.0
        if servers.is_a?(Array) && !servers.empty?
          report_kvs[:RemoteHost] = servers.join(", ")
        end

        if SolarWindsAPM.tracing? && !SolarWindsAPM.tracing_layer_op?(:get_multi)
          SolarWindsAPM::SDK.trace(:memcache, kvs: report_kvs) do
            result = perform_without_sw_apm(*all_args, &blk)

            # Clear the hash for a potential info event
            report_kvs.clear
            report_kvs[:KVHit] = memcache_hit?(result) if op == :get && key.class == String
            report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:dalli][:collect_backtraces]

            result
          end
        else
          perform_without_sw_apm(*all_args, &blk)
        end
      end

      def get_multi_with_sw_apm(*keys)
        return get_multi_without_sw_apm(*keys) unless SolarWindsAPM.tracing?

        info_kvs = {}

        begin
          info_kvs[:KVKeyCount] = keys.flatten.length
          info_kvs[:KVKeyCount] = (info_kvs[:KVKeyCount] - 1) if keys.last.is_a?(Hash) || keys.last.nil?

          servers = @servers || @normalized_servers # name change since Dalli 3.2.1
          if servers.is_a?(Array) && !servers.empty?
            info_kvs[:RemoteHost] = servers.join(", ")
          end
        rescue => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
        end

        info_kvs[:KVOp] = :get_multi
        info_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:dalli][:collect_backtraces]
        SolarWindsAPM::SDK.trace(:memcache, kvs: info_kvs, protect_op: :get_multi) do
          values = get_multi_without_sw_apm(*keys)

          info_kvs[:KVHitCount] = values.length

          values
        end
      end
    end
  end
end

if defined?(Dalli) && SolarWindsAPM::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include SolarWindsAPM::Inst::Dalli
  end
end
