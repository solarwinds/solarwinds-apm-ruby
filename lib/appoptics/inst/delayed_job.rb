# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

if defined?(::Delayed)
  module AppOptics
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
            ::AppOptics::Util.class_method_alias(klass, :after_fork, ::Delayed::Worker)
          end

          def after_fork_with_appoptics
            ::AppOptics.logger.info '[appoptics/delayed_job] Detected fork.  Restarting AppOptics reporter.' if AppOptics::Config[:verbose]
            ::AppOptics::Reporter.restart unless ENV.key?('APPOPTICS_GEM_TEST')

            after_fork_without_appoptics
          end
        end

        ##
        # AppOptics::Inst::DelayedJob::Plugin
        #
        # The AppOptics DelayedJob plugin.  Here we wrap `enqueue` and
        # `perform` to capture the timing of the bits we're interested
        # in.
        #
        class Plugin < Delayed::Plugin
          callbacks do |lifecycle|

            # enqueue
            if AppOptics::Config[:delayed_jobclient][:enabled]
              lifecycle.around(:enqueue) do |job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :pushq
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:delayed_jobclient][:collect_backtraces]

                  AppOptics::API.trace(:'delayed_job-client', report_kvs) do
                    block.call(job)
                  end
                end
              end
            end

            # invoke_job
            if AppOptics::Config[:delayed_jobworker][:enabled]
              lifecycle.around(:perform) do |worker, job, &block|
                begin
                  report_kvs = {}
                  report_kvs[:Spec] = :job
                  report_kvs[:Flavor] = :DelayedJob
                  report_kvs[:JobName] = job.name
                  report_kvs[:MsgID] = job.id
                  report_kvs[:Queue] = job.queue if job.queue
                  report_kvs[:Backtrace] = AppOptics::API.backtrace if AppOptics::Config[:delayed_jobworker][:collect_backtraces]

                  # DelayedJob Specific KVs
                  report_kvs[:priority] = job.priority
                  report_kvs[:attempts] = job.attempts
                  report_kvs[:WorkerName] = job.locked_by
                rescue => e
                  AppOptics.logger.warn "[appoptics/warning] inst/delayed_job.rb: #{e.message}"
                end

                result = AppOptics::API.start_trace(:'delayed_job-worker', nil, report_kvs) do
                  block.call(worker, job)
                  AppOptics::API.log_exception(nil, job.error) if job.error
                end
                result[0]
              end
            end
          end
        end
      end
    end
  end

  ::AppOptics.logger.info '[appoptics/loading] Instrumenting delayed_job' if AppOptics::Config[:verbose]
  ::AppOptics::Util.send_extend(::Delayed::Worker, ::AppOptics::Inst::DelayedJob::ForkHandler)
  ::Delayed::Worker.plugins << ::AppOptics::Inst::DelayedJob::Plugin
end
