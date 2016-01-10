# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module BunnyExchange
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :publish, ::Bunny::Exchange)
        ::TraceView::Util.method_alias(klass, :delete, ::Bunny::Exchange)
      end

      def publish_with_traceview(payload, opts = {})
        # If we're not tracing, just do a fast return.
        return publish_without_traceview(payload, opts) if !TraceView.tracing?

        begin
          kvs = {}
          kvs[:Spec] = :pushq
          kvs[:Flavor] = :rabbitmq # broker name?

          if @name && @name.is_a?(String) && !@name.empty?
            kvs[:ExchangeName] = @name
          else
            kvs[:ExchangeName] = :default
          end

          kvs[:ExchangeType]   = @type
          kvs[:Queue]          = opts[:queue] if opts.key?(:queue)
          kvs[:RoutingKey]     = opts[:routing_key] if opts.key?(:routing_key)
          kvs[:RemoteHost]     = channel.connection.host
          kvs[:RemotePort]     = channel.connection.port

          kvs[:ExchangeAction] = :publish
          kvs[:VirtualHost] = channel.connection.vhost

          TraceView::API.log_entry('rabbitmq')

          publish_without_traceview(payload, opts)
        rescue => e
          TraceView::API.log_exception(nil, e)
          raise e
        ensure
          TraceView::API.log_exit('rabbitmq', kvs)
        end
      end

      def delete_with_traceview(opts = {})
        # If we're not tracing, just do a fast return.
        return delete_without_traceview if !TraceView.tracing?

        begin
          kvs = {}
          kvs[:Spec] = :pushq
          kvs[:Flavor] = :rabbitmq
          kvs[:ExchangeAction] = :delete
          kvs[:ExchangeType]   = @type
          kvs[:RemoteHost]     = channel.connection.host
          kvs[:RemotePort]     = channel.connection.port
          kvs[:VirtualHost] = channel.connection.vhost

          if @name.is_a?(String) && !@name.empty?
            kvs[:ExchangeName] = @name
          else
            kvs[:ExchangeName] = :default
          end

          TraceView::API.log_entry('rabbitmq')

          delete_without_traceview
        rescue => e
          TraceView::API.log_exception(nil, e)
          raise e
        ensure
          TraceView::API.log_exit('rabbitmq', kvs)
        end
      end
    end

    module BunnyChannel
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :wait_for_confirms, ::Bunny::Channel)
      end

      def wait_for_confirms_with_traceview
        # If we're not tracing, just do a fast return.
        return wait_for_confirms_without_traceview if !TraceView.tracing?

        begin
          kvs = {}
          kvs[:Spec] = :pushq
          kvs[:Flavor] = :rabbitmq
          kvs[:ExchangeAction] = :wait_for_confirms
          kvs[:RemoteHost] = @connection.host
          kvs[:RemotePort] = @connection.port
          kvs[:VirtualHost] = @connection.vhost

          if @name.is_a?(String) && !@name.empty?
            kvs[:ExchangeName] = @name
          else
            kvs[:ExchangeName] = :default
          end

          TraceView::API.log_entry('rabbitmq')

          wait_for_confirms_without_traceview
        rescue => e
          TraceView::API.log_exception(nil, e)
          raise e
        ensure
          TraceView::API.log_exit('rabbitmq', kvs)
        end
      end
    end
  end
end

if TraceView::Config[:bunny][:enabled] && defined?(::Bunny)
  ::TraceView.logger.info '[traceview/loading] Instrumenting bunny' if TraceView::Config[:verbose]
  ::TraceView::Util.send_include(::Bunny::Exchange, ::TraceView::Inst::BunnyExchange)
  ::TraceView::Util.send_include(::Bunny::Channel, ::TraceView::Inst::BunnyChannel)
end
