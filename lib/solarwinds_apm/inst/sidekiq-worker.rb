# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  class SidekiqWorker
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.
        report_kvs = {}
        _worker, msg, queue = args

        # Background Job Spec KVs
        report_kvs[:Spec]       = :job
        report_kvs[:Flavor]     = :sidekiq
        report_kvs[:Queue]      = queue
        report_kvs[:Retry]      = msg['retry']
        report_kvs[:JobName]    = msg['wrapped'] || msg['class']
        report_kvs[:MsgID]      = msg['jid']
        report_kvs[:Args]       = msg['args'].to_s[0..1024] if SolarWindsAPM::Config[:sidekiqworker][:log_args]
        report_kvs[:Backtrace]  = SolarWindsAPM::API.backtrace if SolarWindsAPM::Config[:sidekiqworker][:collect_backtraces]

        # Webserver Spec KVs
        report_kvs[:'HTTP-Host'] = Socket.gethostname
        report_kvs[:Controller] = "Sidekiq_#{queue}"
        report_kvs[:Action] = msg['wrapped'] || msg['class']
        report_kvs[:URL] = "/sidekiq/#{queue}/#{msg['wrapped'] || msg['class']}"
      rescue => e
        SolarWindsAPM.logger.warn "[solarwinds_apm/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker, 1: msg, 2: queue
      report_kvs = collect_kvs(args)

      # Continue the trace from the enqueue side
      if args[1].is_a?(Hash) && SolarWindsAPM::TraceString.valid?(args[1]['SourceTrace'])
        report_kvs[:SourceTrace] = args[1]['SourceTrace']
        SolarWindsAPM::Context.fromString(args[1]['SourceTrace'])
        args[1].delete('SourceTrace')
        unless args[1]['traceparent'] && args[1]['tracestate']
          add_tracecontext_headers(args[1])
        end
      end

      SolarWindsAPM::SDK.start_trace(:'sidekiq-worker', kvs: report_kvs, headers: args[1]) do
        yield
      end
    end
  end
end

if defined?(Sidekiq) && SolarWindsAPM::Config[:sidekiqworker][:enabled]
  SolarWindsAPM.logger.info '[solarwinds_apm/loading] Instrumenting sidekiq worker' if SolarWindsAPM::Config[:verbose]

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      SolarWindsAPM.logger.info '[solarwinds_apm/loading] Adding Sidekiq worker middleware' if SolarWindsAPM::Config[:verbose]
      chain.add SolarWindsAPM::SidekiqWorker
    end
  end
end
