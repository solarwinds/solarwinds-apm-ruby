# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module Inst
    module BunnyConsumer
      include SolarWindsAPM::SDK::TraceContextHeaders

      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :call, ::Bunny::Consumer)
      end

      def collect_consumer_kvs(args)
        kvs = {}
        kvs[:Spec] = :job
        kvs[:Flavor] = :rabbitmq
        kvs[:RemoteHost] = @channel.connection.host
        kvs[:RemotePort] = @channel.connection.port.to_i
        kvs[:VirtualHost] = @channel.connection.vhost

        mp = args[1]
        kvs[:RoutingKey] = args[0].routing_key if args[0].routing_key
        kvs[:MsgID] = args[1].message_id if mp.message_id
        kvs[:AppID] = args[1].app_id if mp.app_id
        kvs[:Priority] = args[1].priority if mp.priority

        if @queue.respond_to?(:name)
          kvs[:Queue] = @queue.name
        else
          kvs[:Queue] = @queue
        end

        # Report configurable Controller/Action KVs
        # See SolarWindsAPM::Config[:bunnyconsumer] in lib/solarwinds_apm/config.rb
        # Used for dashboard trace filtering
        controller_key = SolarWindsAPM::Config[:bunnyconsumer][:controller]
        if mp.respond_to?(controller_key)
          value = mp.method(controller_key).call
          kvs[:Controller] = value if value
        end

        action_key = SolarWindsAPM::Config[:bunnyconsumer][:action]
        if mp.respond_to?(action_key)
          value = mp.method(action_key).call
          kvs[:Action] = value if value
        end

        if kvs[:Queue]
          kvs[:URL] = "/bunny/#{kvs[:Queue]}"
        else
          kvs[:URL] = "/bunny/consumer"
        end

        if SolarWindsAPM::Config[:bunnyconsumer][:log_args] && @arguments
          kvs[:Args] = @arguments.to_s
        end

        kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:bunnyconsumer][:collect_backtraces]

        kvs
      rescue => e
        SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
      ensure
        return kvs
      end

      def call_with_sw_apm(*args)
        report_kvs = collect_consumer_kvs(args)

        # TODO all of this (to the next empty line) can be removed
        #  once all of our agents (actually only Node) use w3c-header for RabbitMQ
        #  w3c headers are read and added by the logging code
        # If SourceTrace was passed:
        # - capture it, report it
        # - and add it as traceparent and tracestate header for use by start_trace
        headers = args[1][:headers]
        if headers && headers['SourceTrace']
          report_kvs[:SourceTrace] = headers['SourceTrace']
          # Remove SourceTrace
          headers.delete('SourceTrace')
          unless headers['traceparent'] && headers['tracestate']
            add_tracecontext_headers(headers)
          end
        end

        # the context either gets propagated via w3c headers
        # or a new one should be started
        # lets clear any context that may exist
        # TODO revert with NH-11132
        SolarWindsAPM::Context.clear
        SolarWindsAPM::SDK.start_trace(:'rabbitmq-consumer', kvs: report_kvs, headers: headers) do
          call_without_sw_apm(*args)
        end
      end
    end
  end
end

if SolarWindsAPM::Config[:bunnyconsumer][:enabled] && defined?(Bunny)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting bunny consumer' if SolarWindsAPM::Config[:verbose]
  SolarWindsAPM::Util.send_include(Bunny::Consumer, SolarWindsAPM::Inst::BunnyConsumer)
end
