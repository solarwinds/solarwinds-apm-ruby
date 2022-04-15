# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'socket'
require 'json'

module SolarWindsAPM
  module Inst
    module ResqueClient

      self.include SolarWindsAPM::SDK::TraceContextHeaders

      def extract_trace_details(klass, args)
        report_kvs = {}

        begin
          report_kvs[:Spec] = :pushq
          report_kvs[:Flavor] = :resque
          report_kvs[:JobName] = klass.to_s

          if SolarWindsAPM::Config[:resqueclient][:log_args]
            kv_args = args.to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end
          report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:resqueclient][:collect_backtraces]
          report_kvs[:Queue] = klass.instance_variable_get(:@queue)
        rescue => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
        end

        report_kvs
      end

      def push(queue, item)
        if SolarWindsAPM.tracing?
          report_kvs = extract_trace_details(item[:class], item[:args])
          report_kvs[:Queue] = queue.to_s if queue

          SolarWindsAPM::SDK.trace(:'resque-client', kvs: report_kvs) do
            add_tracecontext_headers(item)
            super
          end
        else
          super
        end
      end

      def dequeue(klass, *args)
        if SolarWindsAPM.tracing?
          report_kvs = extract_trace_details(klass, args)
          SolarWindsAPM::SDK.trace(:'resque-client', kvs: report_kvs) do
            super(klass, *args)
          end
        else
          super(klass, *args)
        end
      end
    end

    module ResqueJob

      def perform
        report_kvs = {}

        begin
          report_kvs[:Spec] = :job
          report_kvs[:Flavor] = :resque
          report_kvs[:JobName] = payload['class'].to_s
          report_kvs[:Queue] = queue.to_s

          # Set these keys for the ability to separate out
          # background tasks into a separate app on the server-side UI

          report_kvs[:'HTTP-Host'] = Socket.gethostname
          report_kvs[:Controller] = "Resque_#{queue}"
          report_kvs[:Action] = payload['class'].to_s
          report_kvs[:URL] = "/resque/#{queue}/#{payload['class']}"

          if SolarWindsAPM::Config[:resqueworker][:log_args]
            kv_args = payload['args'].to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:resqueworker][:collect_backtraces]
        rescue => e
          SolarWindsAPM.logger.debug "[solarwinds_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if SolarWindsAPM::Config[:verbose]
        end

        SolarWindsAPM::SDK.start_trace('resque-worker', kvs: report_kvs, headers: payload) do
          super
        end

        def fail(exception)
          if SolarWindsAPM.tracing?
            SolarWindsAPM::API.log_exception(:resque, exception)
          end
          super(exception)
        end
      end
    end
  end
end

if defined?(::Resque)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting resque' if SolarWindsAPM::Config[:verbose]

  if SolarWindsAPM::Config[:resqueclient][:enabled]
    ::Resque.singleton_class.prepend(SolarWindsAPM::Inst::ResqueClient)
    ::Resque.singleton_class.prepend(SolarWindsAPM::Inst::ResqueClient)
  end

  if SolarWindsAPM::Config[:resqueclient][:enabled] || SolarWindsAPM::Config[:resqueworker][:enabled]
    Resque::Job.prepend(SolarWindsAPM::Inst::ResqueJob)
  end
end


