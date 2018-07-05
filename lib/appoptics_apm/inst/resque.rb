# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'socket'
require 'json'

module AppOpticsAPM
  module Inst
    module ResqueClient
      def self.included(klass)
        klass.send :extend, ::Resque
        ::AppOpticsAPM::Util.method_alias(klass, :enqueue, ::Resque)
        ::AppOpticsAPM::Util.method_alias(klass, :enqueue_to, ::Resque)
        ::AppOpticsAPM::Util.method_alias(klass, :dequeue, ::Resque)
      end

      def extract_trace_details(op, klass, args)
        report_kvs = {}

        begin
          report_kvs[:Spec] = :pushq
          report_kvs[:Flavor] = :resque
          report_kvs[:JobName] = klass.to_s

          if AppOpticsAPM::Config[:resqueclient][:log_args]
            kv_args = args.to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end
          report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:resqueclient][:collect_backtraces]
          report_kvs[:Queue] = klass.instance_variable_get(:@queue)
        rescue => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        report_kvs
      end

      def enqueue_with_appoptics(klass, *args)
        if AppOpticsAPM.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          AppOpticsAPM::API.trace(:'resque-client', report_kvs, :enqueue) do
            enqueue_without_appoptics(klass, *args)
          end
        else
          enqueue_without_appoptics(klass, *args)
        end
      end

      def enqueue_to_with_appoptics(queue, klass, *args)
        if AppOpticsAPM.tracing? && !AppOpticsAPM.tracing_layer_op?(:enqueue)
          report_kvs = extract_trace_details(:enqueue_to, klass, args)
          report_kvs[:Queue] = queue.to_s if queue

          AppOpticsAPM::API.trace(:'resque-client', report_kvs) do
            enqueue_to_without_appoptics(queue, klass, *args)
          end
        else
          enqueue_to_without_appoptics(queue, klass, *args)
        end
      end

      def dequeue_with_appoptics(klass, *args)
        if AppOpticsAPM.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          AppOpticsAPM::API.trace(:'resque-client', report_kvs) do
            dequeue_without_appoptics(klass, *args)
          end
        else
          dequeue_without_appoptics(klass, *args)
        end
      end
    end

    module ResqueWorker
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :perform, ::Resque::Worker)
      end

      def perform_with_appoptics(job)
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

          if AppOpticsAPM::Config[:resqueworker][:log_args]
            kv_args = job.payload['args'].to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:resqueworker][:collect_backtraces]
        rescue => e
          AppOpticsAPM.logger.debug "[appoptics_apm/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if AppOpticsAPM::Config[:verbose]
        end

        AppOpticsAPM::SDK.start_trace(:'resque-worker', nil, report_kvs) do
          perform_without_appoptics(job)
        end
      end
    end

    module ResqueJob
      def self.included(klass)
        ::AppOpticsAPM::Util.method_alias(klass, :fail, ::Resque::Job)
      end

      def fail_with_appoptics(exception)
        if AppOpticsAPM.tracing?
          AppOpticsAPM::API.log_exception(:resque, exception)
        end
        fail_without_appoptics(exception)
      end
    end
  end
end

if defined?(::Resque)
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting resque' if AppOpticsAPM::Config[:verbose]

  ::AppOpticsAPM::Util.send_include(::Resque,         ::AppOpticsAPM::Inst::ResqueClient) if AppOpticsAPM::Config[:resqueclient][:enabled]
  ::AppOpticsAPM::Util.send_include(::Resque::Worker, ::AppOpticsAPM::Inst::ResqueWorker) if AppOpticsAPM::Config[:resqueworker][:enabled]
  if AppOpticsAPM::Config[:resqueclient][:enabled] || AppOpticsAPM::Config[:resqueworker][:enabled]
    ::AppOpticsAPM::Util.send_include(::Resque::Job,    ::AppOpticsAPM::Inst::ResqueJob)
  end
end


