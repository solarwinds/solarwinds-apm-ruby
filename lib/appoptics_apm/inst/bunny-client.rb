# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Inst
    module BunnyExchange
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :delete, ::Bunny::Exchange)
      end

      def delete_with_appoptics(opts = {})
        # If we're not tracing, just do a fast return.
        return delete_without_appoptics(opts) if !AppOpticsAPM.tracing?

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

          AppOpticsAPM::API.log_entry(:'rabbitmq-client')
          delete_without_appoptics(opts)
        rescue => e
          AppOpticsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end

    module BunnyChannel
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :basic_publish,     ::Bunny::Channel)
        ::AppOpticsAPM::Util.method_alias(klass, :queue,             ::Bunny::Channel)
        ::AppOpticsAPM::Util.method_alias(klass, :wait_for_confirms, ::Bunny::Channel)
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
        AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def basic_publish_with_appoptics(payload, exchange, routing_key, opts = {})
        # If we're not tracing, just do a fast return.
        return basic_publish_without_appoptics(payload, exchange, routing_key, opts) if !AppOpticsAPM.tracing?

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

          AppOpticsAPM::API.log_entry(:'rabbitmq-client')

          # Pass the tracing context as a header
          opts[:headers] ||= {}
          opts[:headers][:SourceTrace] = AppOpticsAPM::Context.toString if AppOpticsAPM.tracing?

          basic_publish_without_appoptics(payload, exchange, routing_key, opts)
        rescue => e
          AppOpticsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def queue_with_appoptics(name = AMQ::Protocol::EMPTY_STRING, opts = {})
        # If we're not tracing, just do a fast return.
        return queue_without_appoptics(name, opts) if !AppOpticsAPM.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :queue

          AppOpticsAPM::API.log_entry(:'rabbitmq-client')

          result = queue_without_appoptics(name, opts)
          kvs[:Queue] = result.name
          result
        rescue => e
          AppOpticsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end

      def wait_for_confirms_with_appoptics
        # If we're not tracing, just do a fast return.
        return wait_for_confirms_without_appoptics if !AppOpticsAPM.tracing?

        begin
          kvs = collect_channel_kvs
          kvs[:Op] = :wait_for_confirms

          AppOpticsAPM::API.log_entry(:'rabbitmq-client')

          wait_for_confirms_without_appoptics
        rescue => e
          AppOpticsAPM::API.log_exception(:'rabbitmq-client', e)
          raise e
        ensure
          kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
          AppOpticsAPM::API.log_exit(:'rabbitmq-client', kvs)
        end
      end
    end
  end
end

if AppOpticsAPM::Config[:bunnyclient][:enabled] && defined?(::Bunny)
  ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting bunny client' if AppOpticsAPM::Config[:verbose]
  ::AppOpticsAPM::Util.send_include(::Bunny::Exchange, ::AppOpticsAPM::Inst::BunnyExchange)
  ::AppOpticsAPM::Util.send_include(::Bunny::Channel, ::AppOpticsAPM::Inst::BunnyChannel)
end
