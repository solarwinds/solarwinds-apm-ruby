# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(Delayed)
  module AppOpticsAPM
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
            AppOpticsAPM::Util.class_method_alias(klass, :after_fork, ::Delayed::Worker)
          end

          def after_fork_with_appoptics
            AppOpticsAPM.logger.info '[appoptics_apm/delayed_job] Detected fork.  Restarting AppOpticsAPM reporter.' if AppOpticsAPM::Config[:verbose]
            AppOpticsAPM::Reporter.restart unless ENV.key?('APPOPTICS_GEM_TEST')

            after_fork_without_appoptics
          end
        end

        ##
        # AppOpticsAPM::Inst::DelayedJob::Plugin
        #
        # The AppOpticsAPM DelayedJob plugin.  Here we wrap `enqueue` and
        # `perform` to capture the timing of the bits we're interested
        # in.
        #
        class Plugin < Delayed::Plugin
          callbacks do |lifecycle|

            # enqueue
            if AppOpticsAPM::Config[:delayed_jobclient][:enabled]
              lifecycle.around(:enqueue) do |job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :pushq
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:delayed_jobclient][:collect_backtraces]

                  AppOpticsAPM::SDK.trace(:'delayed_job-client', kvs: report_kvs) do
                    block.call(job)
                  end
                end
              end
            end

            # invoke_job
            if AppOpticsAPM::Config[:delayed_jobworker][:enabled]
              lifecycle.around(:perform) do |worker, job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :job
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:delayed_jobworker][:collect_backtraces]

                  # DelayedJob Specific KVs
                  report_kvs[:priority] = job.priority
                  report_kvs[:attempts] = job.attempts
                  report_kvs[:WorkerName] = job.locked_by
                rescue => e
                  AppOpticsAPM.logger.warn "[appoptics_apm/warning] inst/delayed_job.rb: #{e.message}"
                end

                AppOpticsAPM::SDK.start_trace(:'delayed_job-worker', kvs: report_kvs) do
                  result = block.call(worker, job)
                  AppOpticsAPM::API.log_exception(:'delayed_job-worker', job.error) if job.error
                  result
                end
              end
            end
          end
        end
      end
    end
  end

  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting delayed_job' if AppOpticsAPM::Config[:verbose]
  AppOpticsAPM::Util.send_extend(::Delayed::Worker, AppOpticsAPM::Inst::DelayedJob::ForkHandler)
  Delayed::Worker.plugins << AppOpticsAPM::Inst::DelayedJob::Plugin
end
