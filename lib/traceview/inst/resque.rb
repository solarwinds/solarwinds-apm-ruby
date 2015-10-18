# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'socket'
require 'json'

module TraceView
  module Inst
    module Resque
      def self.included(base)
        base.send :extend, ::Resque
      end

      def extract_trace_details(op, klass, args)
        report_kvs = {}

        begin
          report_kvs[:Op] = op.to_s
          report_kvs[:Class] = klass.to_s if klass

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
        rescue
        end

        report_kvs
      end

      def enqueue_with_traceview(klass, *args)
        if TraceView.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          TraceView::API.trace('resque-client', report_kvs, :enqueue) do
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

          TraceView::API.trace('resque-client', report_kvs) do
            enqueue_to_without_traceview(queue, klass, *args)
          end
        else
          enqueue_to_without_traceview(queue, klass, *args)
        end
      end

      def dequeue_with_traceview(klass, *args)
        if TraceView.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          TraceView::API.trace('resque-client', report_kvs) do
            dequeue_without_traceview(klass, *args)
          end
        else
          dequeue_without_traceview(klass, *args)
        end
      end
    end

    module ResqueWorker
      def perform_with_traceview(job)
        report_kvs = {}
        last_arg = nil

        begin
          report_kvs[:Op] = :perform

          # Set these keys for the ability to separate out
          # background tasks into a separate app on the server-side UI
          report_kvs[:Controller] = :Resque
          report_kvs[:Action] = :perform

          report_kvs['HTTP-Host'] = Socket.gethostname
          report_kvs[:URL] = '/resque/' + job.queue
          report_kvs[:Method] = 'NONE'
          report_kvs[:Queue] = job.queue

          report_kvs[:Class] = job.payload['class']

          if TraceView::Config[:resque][:log_args]
            kv_args = job.payload['args'].to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          last_arg = job.payload['args'].last
        rescue
        end

        TraceView::API.start_trace('resque-worker', nil, report_kvs) do
          perform_without_traceview(job)
        end
      end
    end

    module ResqueJob
      def fail_with_traceview(exception)
        if TraceView.tracing?
          TraceView::API.log_exception('resque', exception)
        end
        fail_without_traceview(exception)
      end
    end
  end
end

if defined?(::Resque) && RUBY_VERSION > '1.9.3'
  TraceView.logger.info '[traceview/loading] Instrumenting resque' if TraceView::Config[:verbose]

  ::Resque.module_eval do
    include TraceView::Inst::Resque

    [:enqueue, :enqueue_to, :dequeue].each do |m|
      if method_defined?(m)
        module_eval "alias #{m}_without_traceview #{m}"
        module_eval "alias #{m} #{m}_with_traceview"
      elsif TraceView::Config[:verbose]
        TraceView.logger.warn "[traceview/loading] Couldn't properly instrument Resque (#{m}).  Partial traces may occur."
      end
    end
  end

  if defined?(::Resque::Worker)
    ::Resque::Worker.class_eval do
      include TraceView::Inst::ResqueWorker

      if method_defined?(:perform)
        alias perform_without_traceview perform
        alias perform perform_with_traceview
      elsif TraceView::Config[:verbose]
        TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument ResqueWorker (perform).  Partial traces may occur.'
      end
    end
  end

  if defined?(::Resque::Job)
    ::Resque::Job.class_eval do
      include TraceView::Inst::ResqueJob

      if method_defined?(:fail)
        alias fail_without_traceview fail
        alias fail fail_with_traceview
      elsif TraceView::Config[:verbose]
        TraceView.logger.warn '[traceview/loading] Couldn\'t properly instrument ResqueWorker (fail).  Partial traces may occur.'
      end
    end
  end
end


