# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module BunnyExchange
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :delete, ::Bunny::Exchange)
      end

      def delete_with_appoptics(opts = {})
        # If we're not tracing, just do a fast return.
        return delete_without_appoptics(opts) if !SolarWindsAPM.tracing?

        begin
          kvs = {}
          kvs[:Spec] = :pushq
          kvs[:Flavor] = :rabbitmq
          kvs[:Op] = :delete
          kvs[:ExchangeType]   = @type
          kvs[:RemoteHost]     = channel.connection.host
          kvs[:RemotePort]     = channel.connection.port.to_i
          kvs[:VirtualHost] = channel.connection.vhost

          if @name.is_a?(String) && !@name.empty?
            kvs[:ExchangeName] = @name
          else
            kvs[:ExchangeName] = :default
          end

          SolarWindsAPM::API.log_entry(:'rabbitmq-client')
          delete_without_appoptics(opts)
        rescue => e
          SolarWindsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end

    module BunnyChannel
      include SolarWindsAPM::SDK::TraceContextHeaders

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :basic_publish,     ::Bunny::Channel)
        SolarWindsAPM::Util.method_alias(klass, :queue,             ::Bunny::Channel)
        SolarWindsAPM::Util.method_alias(klass, :wait_for_confirms, ::Bunny::Channel)
      end

      def collect_channel_kvs
        kvs = {}
        kvs[:Spec] = :pushq
        kvs[:Flavor] = :rabbitmq
        kvs[:RemoteHost] = @connection.host
        kvs[:RemotePort] = @connection.port.to_i
        kvs[:VirtualHost] = @connection.vhost
        kvs
      rescue => e
        SolarWindsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def basic_publish_with_appoptics(payload, exchange, routing_key, opts = {})
        # If we're not tracing, just do a fast return.
        return basic_publish_without_appoptics(payload, exchange, routing_key, opts) if !SolarWindsAPM.tracing?

        begin
          kvs = collect_channel_kvs

          if exchange.respond_to?(:name)
            kvs[:ExchangeName] = exchange.name
          elsif exchange.respond_to?(:empty?) && !exchange.empty?
            kvs[:ExchangeName] = exchange
          else
            kvs[:ExchangeName] = :default
          end

          kvs[:Queue]       = opts[:queue] if opts.key?(:queue)
          kvs[:RoutingKey]  = routing_key if routing_key
          kvs[:Op]          = :publish

          SolarWindsAPM::API.log_entry(:'rabbitmq-client')

          # Pass the tracing context as a header
          opts[:headers] ||= {}
          opts[:headers][:SourceTrace] = SolarWindsAPM::Context.toString if SolarWindsAPM.tracing?
          add_tracecontext_headers(opts[:headers])

          basic_publish_without_appoptics(payload, exchange, routing_key, opts)
        rescue => e
          SolarWindsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def queue_with_appoptics(name = AMQ::Protocol::EMPTY_STRING, opts = {})
        # If we're not tracing, just do a fast return.
        return queue_without_appoptics(name, opts) if !SolarWindsAPM.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :queue

          SolarWindsAPM::API.log_entry(:'rabbitmq-client')

          result = queue_without_appoptics(name, opts)
          kvs[:Queue] = result.name
          result
        rescue => e
          SolarWindsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def wait_for_confirms_with_appoptics
        # If we're not tracing, just do a fast return.
        return wait_for_confirms_without_appoptics if !SolarWindsAPM.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :wait_for_confirms

          SolarWindsAPM::API.log_entry(:'rabbitmq-client')

          wait_for_confirms_without_appoptics
        rescue => e
          SolarWindsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
          SolarWindsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end
  end
end

if defined?(Bunny) && SolarWindsAPM::Config[:bunnyclient][:enabled]
  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting bunny client' if SolarWindsAPM::Config[:verbose]
  SolarWindsAPM::Util.send_include(Bunny::Exchange, SolarWindsAPM::Inst::BunnyExchange)
  SolarWindsAPM::Util.send_include(Bunny::Channel, SolarWindsAPM::Inst::BunnyChannel)
end
