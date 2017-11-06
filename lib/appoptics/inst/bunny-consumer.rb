# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  module Inst
    module BunnyConsumer
      def self.included(klass)
        ::AppOptics::Util.method_alias(klass, :call, ::Bunny::Consumer)
      end

      def collect_consumer_kvs(args)
        begin
          kvs = {}
          kvs[:Spec] = :job
          kvs[:Flavor] = :rabbitmq
          kvs[:RemoteHost]  = @channel.connection.host
          kvs[:RemotePort]  = @channel.connection.port.to_i
          kvs[:VirtualHost] = @channel.connection.vhost

          mp = args[1]
          kvs[:RoutingKey] = args[0].routing_key if args[0].routing_key
          kvs[:MsgID]      = args[1].message_id  if mp.message_id
          kvs[:AppID]      = args[1].app_id      if mp.app_id
          kvs[:Priority]   = args[1].priority    if mp.priority

          if @queue.respond_to?(:name)
            kvs[:Queue] = @queue.name
          else
            kvs[:Queue] = @queue
          end

          # Report configurable Controller/Action KVs
          # See AppOptics::Config[:bunny] in lib/appoptics/config.rb
          # Used for dashboard trace filtering
          controller_key = AppOptics::Config[:bunnyconsumer][:controller]
          if mp.respond_to?(controller_key)
            value = mp.method(controller_key).call
            kvs[:Controller] = value if value
          end

          action_key = AppOptics::Config[:bunnyconsumer][:action]
          if mp.respond_to?(action_key)
            value = mp.method(action_key).call
            kvs[:Action] = value if value
          end

          if kvs[:Queue]
            kvs[:URL] = "/bunny/#{kvs[:Queue]}"
          else
            kvs[:URL] = "/bunny/consumer"
          end

          if AppOptics::Config[:bunnyconsumer][:log_args] && @arguments
            kvs[:Args] = @arguments.to_s
          end

          kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:bunnyconsumer][:collect_backtraces]

          kvs
        rescue => e
          AppOptics.logger.debug "[appoptics/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOptics::Config[:verbose]
        ensure
          return kvs
        end
      end

      def call_with_appoptics(*args)
        report_kvs = collect_consumer_kvs(args)

        # If SourceTrace was passed, capture and report it
        headers = args[1][:headers]

        if headers && headers['SourceTrace']
          report_kvs[:SourceTrace] = headers['SourceTrace']

          # Remove SourceTrace
          headers.delete('SourceTrace')
        end

        result = AppOptics::API.start_trace(:'rabbitmq-consumer', nil, report_kvs) do
          call_without_appoptics(*args)
        end
        result[0]
      end
    end
  end
end

if AppOptics::Config[:bunnyconsumer][:enabled] && defined?(::Bunny)
  ::AppOptics.logger.info '[appoptics/loading] Instrumenting bunny consumer' if AppOptics::Config[:verbose]
  ::AppOptics::Util.send_include(::Bunny::Consumer, ::AppOptics::Inst::BunnyConsumer)
end
