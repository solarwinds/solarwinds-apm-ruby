# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(Delayed)
  module SolarWindsAPM
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
            SolarWindsAPM::Util.class_method_alias(klass, :after_fork, ::Delayed::Worker)
          end

          def after_fork_with_appoptics
            SolarWindsAPM.logger.info '[appoptics_apm/delayed_job] Detected fork.  Restarting SolarWindsAPM reporter.' if SolarWindsAPM::Config[:verbose]
            SolarWindsAPM::Reporter.restart unless ENV.key?('SW_AMP_GEM_TEST')

            after_fork_without_appoptics
          end
        end

        ##
        # SolarWindsAPM::Inst::DelayedJob::Plugin
        #
        # The SolarWindsAPM DelayedJob plugin.  Here we wrap `enqueue` and
        # `perform` to capture the timing of the bits we're interested
        # in.
        #
        class Plugin < Delayed::Plugin
          callbacks do |lifecycle|

            # enqueue
            if SolarWindsAPM::Config[:delayed_jobclient][:enabled]
              lifecycle.around(:enqueue) do |job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :pushq
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:delayed_jobclient][:collect_backtraces]

                  SolarWindsAPM::SDK.trace(:'delayed_job-client', kvs: report_kvs) do
                    block.call(job)
                  end
                end
              end
            end

            # invoke_job
            if SolarWindsAPM::Config[:delayed_jobworker][:enabled]
              lifecycle.around(:perform) do |worker, job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :job
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:delayed_jobworker][:collect_backtraces]

                  # DelayedJob Specific KVs
                  report_kvs[:priority] = job.priority
                  report_kvs[:attempts] = job.attempts
                  report_kvs[:WorkerName] = job.locked_by
                rescue => e
                  SolarWindsAPM.logger.warn "[appoptics_apm/warning] inst/delayed_job.rb: #{e.message}"
                end

                SolarWindsAPM::SDK.start_trace(:'delayed_job-worker', kvs: report_kvs) do
                  result = block.call(worker, job)
                  SolarWindsAPM::API.log_exception(:'delayed_job-worker', job.error) if job.error
                  result
                end
              end
            end
          end
        end
      end
    end
  end

  SolarWindsAPM.logger.info '[appoptics_apm/loading] Instrumenting delayed_job' if SolarWindsAPM::Config[:verbose]
  SolarWindsAPM::Util.send_extend(::Delayed::Worker, SolarWindsAPM::Inst::DelayedJob::ForkHandler)
  Delayed::Worker.plugins << SolarWindsAPM::Inst::DelayedJob::Plugin
end
