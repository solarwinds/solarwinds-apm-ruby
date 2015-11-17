module TraceView
  module Inst
    module DelayedJob
      ##
      # ForkHandler
      #
      # Since delayed job doesn't offer a hook into `after_fork`, we alias the method
      # here to do our magic after a fork happens.
      #
      module ForkHandler
        def self.extended(klass)
          ::TraceView::Util.class_method_alias(klass, :after_fork, ::Delayed::Worker)
        end

        def after_fork_with_traceview
          ::TraceView.logger.info '[traceview/delayed_job] Detected fork.  Restarting TraceView reporter.' if TraceView::Config[:verbose]
          ::TraceView::Reporter.restart

          after_fork_without_traceview
        end
      end

      ##
      # TraceView::Inst::DelayedJob::Plugin
      #
      # The TraceView DelayedJob plugin.  Here we wrap `enqueue` and
      # `perform` to capture the timing of the bits we're interested
      # in.
      #
      class Plugin < Delayed::Plugin
        callbacks do |lifecycle|

          # enqueue
          lifecycle.around(:enqueue) do |job, &block|
            begin
              report_kvs = {}

              TraceView::API.log_entry('delayed_job-client', report_kvs)

              block.call(job)
            rescue => e
              TraceView::API.log_exception('delayed_job-client', e, report_kvs)
              raise
            ensure
              TraceView::API.log_exit('delayed_job-client', report_kvs)
            end
          end

          # perform
          lifecycle.around(:perform) do |worker, job, &block|
            begin
              report_kvs = {}

              result = TraceView::API.start_trace('delayed_job-worker', nil, report_kvs) do
                block.call(worker, job)
              end
              result[0]
            end
          end
        end
      end
    end
  end
end

if defined?(::Delayed::Worker) && TraceView::Config[:delayed_jobworker][:enabled]
  ::TraceView.logger.info '[traceview/loading] Instrumenting delayed_job' if TraceView::Config[:verbose]
  ::TraceView::Util.send_extend(::Delayed::Worker, ::TraceView::Inst::DelayedJob::ForkHandler)
  ::Delayed::Worker.plugins << ::TraceView::Inst::DelayedJob::Plugin
end
