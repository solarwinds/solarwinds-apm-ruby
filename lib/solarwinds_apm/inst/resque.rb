# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'socket'
require 'json'

module SolarWindsAPM
  module Inst
    module ResqueClient
      def self.included(klass)
        klass.send :extend, ::Resque
        SolarWindsAPM::Util.method_alias(klass, :enqueue, ::Resque)
        SolarWindsAPM::Util.method_alias(klass, :enqueue_to, ::Resque)
        SolarWindsAPM::Util.method_alias(klass, :dequeue, ::Resque)
      end

      def extract_trace_details(op, klass, args)
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

      def enqueue_with_sw_apm(klass, *args)
        if SolarWindsAPM.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          SolarWindsAPM::SDK.trace(:'resque-client', kvs: report_kvs, protect_op: :enqueue) do
            enqueue_without_sw_apm(klass, *args)
          end
        else
          enqueue_without_sw_apm(klass, *args)
        end
      end

      def enqueue_to_with_sw_apm(queue, klass, *args)
        if SolarWindsAPM.tracing? && !SolarWindsAPM.tracing_layer_op?(:enqueue)
          report_kvs = extract_trace_details(:enqueue_to, klass, args)
          report_kvs[:Queue] = queue.to_s if queue

          SolarWindsAPM::SDK.trace(:'resque-client', kvs: report_kvs) do
            enqueue_to_without_sw_apm(queue, klass, *args)
          end
        else
          enqueue_to_without_sw_apm(queue, klass, *args)
        end
      end

      def dequeue_with_sw_apm(klass, *args)
        if SolarWindsAPM.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          SolarWindsAPM::SDK.trace(:'resque-client', kvs: report_kvs) do
            dequeue_without_sw_apm(klass, *args)
          end
        else
          dequeue_without_sw_apm(klass, *args)
        end
      end
    end

    module ResqueWorker
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :perform, ::Resque::Worker)
      end

      def perform_with_sw_apm(job)
        report_kvs = {}

        begin
          report_kvs[:Spec] = :job
          report_kvs[:Flavor] = :resque
          report_kvs[:JobName] = job.payload['class'].to_s
          report_kvs[:Queue] = job.queue

          # Set these keys for the ability to separate out
          # background tasks into a separate app on the server-side UI

          report_kvs[:'HTTP-Host'] = Socket.gethostname
          report_kvs[:Controller] = "Resque_#{job.queue}"
          report_kvs[:Action] = job.payload['class'].to_s
          report_kvs[:URL] = "/resque/#{job.queue}/#{job.payload['class']}"

          if SolarWindsAPM::Config[:resqueworker][:log_args]
            kv_args = job.payload['args'].to_json

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

        SolarWindsAPM::SDK.start_trace(:'resque-worker', kvs: report_kvs) do
          perform_without_sw_apm(job)
        end
      end
    end

    module ResqueJob
      def self.included(klass)
        SolarWindsAPM::Util.method_alias(klass, :fail, ::Resque::Job)
      end

      def fail_with_sw_apm(exception)
        if SolarWindsAPM.tracing?
          SolarWindsAPM::API.log_exception(:resque, exception)
        end
        fail_without_sw_apm(exception)
      end
    end
  end
end

if defined?(Resque)
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting resque' if SolarWindsAPM::Config[:verbose]

  SolarWindsAPM::Util.send_include(Resque,         SolarWindsAPM::Inst::ResqueClient) if SolarWindsAPM::Config[:resqueclient][:enabled]
  SolarWindsAPM::Util.send_include(Resque::Worker, SolarWindsAPM::Inst::ResqueWorker) if SolarWindsAPM::Config[:resqueworker][:enabled]
  if SolarWindsAPM::Config[:resqueclient][:enabled] || SolarWindsAPM::Config[:resqueworker][:enabled]
    SolarWindsAPM::Util.send_include(Resque::Job,    SolarWindsAPM::Inst::ResqueJob)
  end
end


