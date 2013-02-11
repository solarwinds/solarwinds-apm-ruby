# Copyright (c) 2013 by Tracelytics, Inc.
# All rights reserved.

module Oboe
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
          report_kvs[:Args] = args.to_json if args
          
          report_kvs[:Backtrace] = Oboe::API.backtrace
        rescue
        end

        report_kvs
      end

      def enqueue_with_oboe(klass, *args)
        if Oboe::Config.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          Oboe::API.trace('resque', report_kvs, :enqueue) do
            args.push({:parent_trace_id => Oboe::Context.toString})
            enqueue_without_oboe(klass, *args)
          end
        else
          enqueue_without_oboe(klass, *args)
        end
      end

      def enqueue_to_with_oboe(queue, klass, *args)
        if Oboe::Config.tracing? and not Oboe::Context.tracing_layer_op?(:enqueue)
          report_kvs = extract_trace_details(:enqueue_to, klass, args)
          report_kvs[:Queue] = queue.to_s if queue

          Oboe::API.trace('resque', report_kvs) do
            args.push({:parent_trace_id => Oboe::Context.toString})
            enqueue_to_without_oboe(queue, klass, *args)
          end
        else
          enqueue_to_without_oboe(queue, klass, *args)
        end
      end

      def dequeue_with_oboe(klass, *args)
        if Oboe::Config.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          Oboe::API.trace('resque', report_kvs) do
            dequeue_without_oboe(klass, *args)
          end
        else
          dequeue_without_oboe(klass, *args)
        end
      end
    end

    module ResqueWorker
      def perform_with_oboe(job)
        report_kvs = {}
        report_kvs[:Op] = :perform

        begin
          last_arg = job.payload['args'].last

          if last_arg.is_a?(Hash) and last_arg.has_key?('parent_trace_id')
            # Since the enqueue was traced, we force trace the actual job execution and reference
            # the enqueue trace with ParentTraceID
            report_kvs[:ParentTraceID] = last_arg['parent_trace_id']
            job.payload['args'].pop

            Oboe::API.force_trace do
              Oboe::API.start_trace('resque', nil, report_kvs) do
                perform_without_oboe(job)
              end
            end

          else
            Oboe::API.start_trace('resque', nil, report_kvs) do
              perform_without_oboe(job)
            end
          end
        rescue
        end
      end
    end

    module ResqueJob
      def fail_with_oboe(exception)
        if Oboe::Config.tracing?
          Oboe::API.log_exception('resque', exception)
        end
        fail_without_oboe(exception)
      end
    end
  end
end

if defined?(::Resque)
  puts "[oboe/loading] Instrumenting resque" if Oboe::Config[:verbose]

  ::Resque.module_eval do
    include Oboe::Inst::Resque

    [ :enqueue, :enqueue_to, :dequeue ].each do |m|
      if method_defined?(m)
        module_eval "alias #{m}_without_oboe #{m}"
        module_eval "alias #{m} #{m}_with_oboe"
      elsif Oboe::Config[:verbose]
        puts "[oboe/loading] Couldn't properly instrument Resque (#{m}).  Partial traces may occur."
      end
    end
  end

  if defined?(::Resque::Worker)
    ::Resque::Worker.class_eval do
      include Oboe::Inst::ResqueWorker

      if method_defined?(:perform)
        alias perform_without_oboe perform
        alias perform perform_with_oboe
      elsif Oboe::Config[:verbose]
        puts "[oboe/loading] Couldn't properly instrument ResqueWorker (perform).  Partial traces may occur."
      end
    end
  end

  if defined?(::Resque::Job)
    ::Resque::Job.class_eval do
      include Oboe::Inst::ResqueJob

      if method_defined?(:fail)
        alias fail_without_oboe fail
        alias fail fail_with_oboe
      elsif Oboe::Config[:verbose]
        puts "[oboe/loading] Couldn't properly instrument ResqueWorker (fail).  Partial traces may occur."
      end
    end
  end
end


