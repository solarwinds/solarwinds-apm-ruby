# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  class SidekiqClient
    include SolarWindsAPM::SDK::TraceContextHeaders

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
        report_kvs[:Args]      = msg['args'].to_s[0..1024] if SolarWindsAPM::Config[:sidekiqclient][:log_args]
        report_kvs[:Backtrace] = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:sidekiqclient][:collect_backtraces]
      rescue => e
        SolarWindsAPM.logger.warn "[solarwinds_apm/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker_class, 1: msg, 2: queue, 3: redis_pool
      if SolarWindsAPM.tracing?
        report_kvs = collect_kvs(args)
        SolarWindsAPM::API.log_entry(:'sidekiq-client', report_kvs)
        if args[1].is_a?(Hash)
          # We've been doing this since 2015, but ...
          # ... is it actually safe to inject our entries into the msg of the job?
          # Opentelemetry does it too :), so I guess we're good
          args[1]['SourceTrace'] = SolarWindsAPM::Context.toString
          add_tracecontext_headers(args[1])
        end
      end

      result = yield
    rescue => e
      SolarWindsAPM::API.log_exception(:'sidekiq-client', e, { :JobID => result['jid'] })
      raise
    ensure
      SolarWindsAPM::API.log_exit(:'sidekiq-client', { :JobID => result['jid'] })
    end
  end
end

if defined?(Sidekiq) && SolarWindsAPM::Config[:sidekiqclient][:enabled]
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting sidekiq client' if SolarWindsAPM::Config[:verbose]

  Sidekiq.configure_client do |config|
    config.client_middleware do |chain|
      SolarWindsAPM.logger.info '[solarwinds_apm/loading] Adding Sidekiq client middleware' if SolarWindsAPM::Config[:verbose]
      chain.add SolarWindsAPM::SidekiqClient
    end
  end
end
