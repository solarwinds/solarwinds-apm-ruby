# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'socket'
require 'json'

module TraceView
  module Inst
    module ResqueClient
      def self.included(klass)
        klass.send :extend, ::Resque
        ::TraceView::Util.method_alias(klass, :enqueue, ::Resque)
        ::TraceView::Util.method_alias(klass, :enqueue_to, ::Resque)
        ::TraceView::Util.method_alias(klass, :dequeue, ::Resque)
      end

      def extract_trace_details(op, klass, args)
        report_kvs = {}

        begin
          report_kvs[:Spec] = :pushq
          report_kvs[:Flavor] = :resque
          report_kvs[:JobName] = klass.to_s

          if TraceView::Config[:resqueclient][:log_args]
            kv_args = args.to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end
          report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:resqueclient][:collect_backtraces]
          report_kvs[:Queue] = klass.instance_variable_get(:@queue)
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        report_kvs
      end

      def enqueue_with_traceview(klass, *args)
        if TraceView.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          TraceView::API.trace(:'resque-client', report_kvs, :enqueue) do
            enqueue_without_traceview(klass, *args)
          end
        else
          enqueue_without_traceview(klass, *args)
        end
      end

      def enqueue_to_with_traceview(queue, klass, *args)
        if TraceView.tracing? && !TraceView.tracing_layer_op?(:enqueue)
          report_kvs = extract_trace_details(:enqueue_to, klass, args)
          report_kvs[:Queue] = queue.to_s if queue

          TraceView::API.trace(:'resque-client', report_kvs) do
            enqueue_to_without_traceview(queue, klass, *args)
          end
        else
          enqueue_to_without_traceview(queue, klass, *args)
        end
      end

      def dequeue_with_traceview(klass, *args)
        if TraceView.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          TraceView::API.trace(:'resque-client', report_kvs) do
            dequeue_without_traceview(klass, *args)
          end
        else
          dequeue_without_traceview(klass, *args)
        end
      end
    end

    module ResqueWorker
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :perform, ::Resque::Worker)
      end

      def perform_with_traceview(job)
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

          if TraceView::Config[:resqueworker][:log_args]
            kv_args = job.payload['args'].to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          report_kvs[:Backtrace] = TraceView::API.backtrace if TraceView::Config[:resqueworker][:collect_backtraces]
        rescue => e
          TraceView.logger.debug "[traceview/debug] #{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" if TraceView::Config[:verbose]
        end

        TraceView::API.start_trace(:'resque-worker', nil, report_kvs) do
          perform_without_traceview(job)
        end
      end
    end

    module ResqueJob
      def self.included(klass)
        ::TraceView::Util.method_alias(klass, :fail, ::Resque::Job)
      end

      def fail_with_traceview(exception)
        if TraceView.tracing?
          TraceView::API.log_exception(:resque, exception)
        end
        fail_without_traceview(exception)
      end
    end
  end
end

if defined?(::Resque) && RUBY_VERSION >= '1.9.3'
  TraceView.logger.info '[traceview/loading] Instrumenting resque' if TraceView::Config[:verbose]

  ::TraceView::Util.send_include(::Resque,         ::TraceView::Inst::ResqueClient)
  ::TraceView::Util.send_include(::Resque::Worker, ::TraceView::Inst::ResqueWorker)
  ::TraceView::Util.send_include(::Resque::Job,    ::TraceView::Inst::ResqueJob)
end


