# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  class SidekiqClient
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.

        report_kvs = {}
        worker_class, msg, queue, _ = args

        report_kvs[:Spec]      = :pushq
        report_kvs[:Flavor]    = :sidekiq
        report_kvs[:Queue]     = queue
        report_kvs[:Retry]     = msg['retry']
        report_kvs[:JobName]   = msg['wrapped'] || worker_class
        report_kvs[:MsgID]     = msg['jid']
        report_kvs[:Args]      = msg['args'].to_s[0..1024] if AppOpticsAPM::Config[:sidekiqclient][:log_args]
        report_kvs[:Backtrace] = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:sidekiqclient][:collect_backtraces]
      rescue => e
        AppOpticsAPM.logger.warn "[appoptics_apm/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker_class, 1: msg, 2: queue, 3: redis_pool
      if AppOpticsAPM.tracing?
        report_kvs = collect_kvs(args)
        AppOpticsAPM::API.log_entry(:'sidekiq-client', report_kvs)
        args[1]['SourceTrace'] = AppOpticsAPM::Context.toString
      end

      result = yield
    rescue => e
      AppOpticsAPM::API.log_exception(:'sidekiq-client', e, { :JobID => result['jid'] })
      raise
    ensure
      AppOpticsAPM::API.log_exit(:'sidekiq-client', { :JobID => result['jid'] })
    end
  end
end

if defined?(::Sidekiq) && AppOpticsAPM::Config[:sidekiqclient][:enabled]
  ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting sidekiq client' if AppOpticsAPM::Config[:verbose]

  ::Sidekiq.configure_client do |config|
    config.client_middleware do |chain|
      ::AppOpticsAPM.logger.info '[appoptics_apm/loading] Adding Sidekiq client middleware' if AppOpticsAPM::Config[:verbose]
      chain.add ::AppOpticsAPM::SidekiqClient
    end
  end
end
