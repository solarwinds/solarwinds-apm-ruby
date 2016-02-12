# Copyright (c) 2016 AppNeta, Inc.
# All rights reserved.

module TraceView
  module Inst
    module BunnyConsumer
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :call, ::Bunny::Consumer)
      end

      def collect_consumer_kvs(args)
        begin
          kvs = {}
          kvs[:Spec] = :job
          kvs[:Flavor] = :rabbitmq
          kvs[:RemoteHost]  = @channel.connection.host
          kvs[:RemotePort]  = @channel.connection.port.to_i
          kvs[:VirtualHost] = @channel.connection.vhost

          if args[0].respond_to?(:routing_key)
            kvs[:RoutingKey] = args[0][:routing_key]
          end

          if @queue.respond_to?(:name)
            kvs[:Queue] = @queue.name
          else
            kvs[:Queue] = @queue
          end

          if TV::Config[:bunnyconsumer][:log_args] && @arguments
            kvs[:Args] = @arguments.to_s
          end

          report_kvs[:Backtrace] = TV::API.backtrace if TV::Config[:bunnyconsumer][:collect_backtraces]

          kvs
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        ensure
          return kvs
        end
      end

      def call_with_traceview(*args)
        report_kvs = collect_consumer_kvs(args)

        result = TraceView::API.start_trace('rabbitmq-consumer', nil, report_kvs) do
          call_without_traceview(*args)
        end
        result[0]
      end
    end
  end
end

if TraceView::Config[:bunnyconsumer][:enabled] && defined?(::Bunny)
  ::TraceView.logger.info '[traceview/loading] Instrumenting bunny consumer' if TraceView::Config[:verbose]
  ::TraceView::Util.send_include(::Bunny::Consumer, ::TraceView::Inst::BunnyConsumer)
end
