# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module Dalli
      include AppOptics::API::Memcache

      def self.included(cls)
        cls.class_eval do
          AppOptics.logger.info '[appoptics/loading] Instrumenting memcache (dalli)' if AppOptics::Config[:verbose]
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_appoptics perform
            alias perform perform_with_appoptics
          else AppOptics.logger.warn '[appoptics/loading] Couldn\'t properly instrument Memcache (Dalli).  Partial traces may occur.'
          end

          if ::Dalli::Client.method_defined? :get_multi
            alias get_multi_without_appoptics get_multi
            alias get_multi get_multi_with_appoptics
          end
        end
      end

      def perform_with_appoptics(*all_args, &blk)
        op, key, *args = *all_args

        report_kvs = {}
        report_kvs[:KVOp] = op
        report_kvs[:KVKey] = key
        if @servers.is_a?(Array) && !@servers.empty?
          report_kvs[:RemoteHost] = @servers.join(", ")
        end

        if AppOptics.tracing? && !AppOptics.tracing_layer_op?(:get_multi)
          AppOptics::API.trace(:memcache, report_kvs) do
            result = perform_without_appoptics(*all_args, &blk)

            # Clear the hash for a potential info event
            report_kvs.clear
            report_kvs[:KVHit] = memcache_hit?(result) if op == :get && key.class == String
            report_kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:dalli][:collect_backtraces]

            AppOptics::API.log(:memcache, :info, report_kvs) unless report_kvs.empty?
            result
          end
        else
          perform_without_appoptics(*all_args, &blk)
        end
      end

      def get_multi_with_appoptics(*keys)
        return get_multi_without_appoptics(*keys) unless AppOptics.tracing?

        info_kvs = {}

        begin
          info_kvs[:KVKeyCount] = keys.flatten.length
          info_kvs[:KVKeyCount] = (info_kvs[:KVKeyCount] - 1) if keys.last.is_a?(Hash) || keys.last.nil?
          if @servers.is_a?(Array) && !@servers.empty?
            info_kvs[:RemoteHost] = @servers.join(", ")
          end
        rescue => e
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        end

        AppOptics::API.trace(:memcache, { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_appoptics(*keys)

          info_kvs[:KVHitCount] = values.length
          info_kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:dalli][:collect_backtraces]
          AppOptics::API.log(:memcache, :info, info_kvs)

          values
        end
      end
    end
  end
end

if defined?(Dalli) && AppOptics::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include AppOptics::Inst::Dalli
  end
end
