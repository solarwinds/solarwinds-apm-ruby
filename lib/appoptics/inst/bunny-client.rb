# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module BunnyExchange
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :delete, ::Bunny::Exchange)
      end

      def delete_with_appoptics(opts = {})
        # If we're not tracing, just do a fast return.
        return delete_without_appoptics(opts) if !AppOptics.tracing?

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

          AppOptics::API.log_entry(:'rabbitmq-client')

          delete_without_appoptics(opts)
        rescue => e
          AppOptics::API.log_exception(nil, e)
          raise e
        ensure
          AppOptics::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end

    module BunnyChannel
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :basic_publish,     ::Bunny::Channel)
        ::AppOptics::Util.method_alias(klass, :queue,             ::Bunny::Channel)
        ::AppOptics::Util.method_alias(klass, :wait_for_confirms, ::Bunny::Channel)
      end

      def collect_channel_kvs
        begin
          kvs = {}
          kvs[:Spec] = :pushq
          kvs[:Flavor] = :rabbitmq
          kvs[:RemoteHost] = @connection.host
          kvs[:RemotePort] = @connection.port.to_i
          kvs[:VirtualHost] = @connection.vhost
          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:bunnyclient][:collect_backtraces]
          kvs
        rescue => e
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        ensure
          return kvs
        end
      end

      def basic_publish_with_appoptics(payload, exchange, routing_key, opts = {})
        # If we're not tracing, just do a fast return.
        return basic_publish_without_appoptics(payload, exchange, routing_key, opts) if !AppOptics.tracing?

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

          AppOptics::API.log_entry(:'rabbitmq-client')

          # Pass the tracing context as a header
          opts[:headers] ||= {}
          opts[:headers][:SourceTrace] = AppOptics::Context.toString if AppOptics.tracing?

          basic_publish_without_appoptics(payload, exchange, routing_key, opts)
        rescue => e
          AppOptics::API.log_exception(nil, e)
          raise e
        ensure
          AppOptics::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def queue_with_appoptics(name = AMQ::Protocol::EMPTY_STRING, opts = {})
        # If we're not tracing, just do a fast return.
        return queue_without_appoptics(name, opts) if !AppOptics.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :queue

          AppOptics::API.log_entry(:'rabbitmq-client')

          result = queue_without_appoptics(name, opts)
          kvs[:Queue] = result.name
          result
        rescue => e
          AppOptics::API.log_exception(nil, e)
          raise e
        ensure
          AppOptics::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def wait_for_confirms_with_appoptics
        # If we're not tracing, just do a fast return.
        return wait_for_confirms_without_appoptics if !AppOptics.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :wait_for_confirms

          AppOptics::API.log_entry(:'rabbitmq-client')

          wait_for_confirms_without_appoptics
        rescue => e
          AppOptics::API.log_exception(nil, e)
          raise e
        ensure
          AppOptics::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end
  end
end

if AppOptics::Config[:bunnyclient][:enabled] && defined?(::Bunny)
  ::AppOptics.logger.info '[appoptics/loading] Instrumenting bunny client' if AppOptics::Config[:verbose]
  ::AppOptics::Util.send_include(::Bunny::Exchange, ::AppOptics::Inst::BunnyExchange)
  ::AppOptics::Util.send_include(::Bunny::Channel, ::AppOptics::Inst::BunnyChannel)
end
