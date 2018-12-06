# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
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
        report_kvs[:Args]       = msg['args'].to_s[0..1024] if AppOpticsAPM::Config[:sidekiqworker][:log_args]
        report_kvs[:Backtrace]  = AppOpticsAPM::API.backtrace if AppOpticsAPM::Config[:sidekiqworker][:collect_backtraces]

        # Webserver Spec KVs
        report_kvs[:'HTTP-Host'] = Socket.gethostname
        report_kvs[:Controller] = "Sidekiq_#{queue}"
        report_kvs[:Action] = msg['wrapped'] || msg['class']
        report_kvs[:URL] = "/sidekiq/#{queue}/#{msg['wrapped'] || msg['class']}"
      rescue => e
        AppOpticsAPM.logger.warn "[appoptics_apm/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker, 1: msg, 2: queue
      report_kvs = collect_kvs(args)

      # Something is happening across Celluloid threads where liboboe settings
      # are being lost.  So we re-set the tracing mode to assure
      # we sample as desired.  Setting the tracing mode will re-update
      # the liboboe settings.
      AppOpticsAPM::Config[:tracing_mode] = AppOpticsAPM::Config[:tracing_mode]

      # Continue the trace from the enqueue side?
      if args[1].is_a?(Hash) && AppOpticsAPM::XTrace.valid?(args[1]['SourceTrace'])
        report_kvs[:SourceTrace] = args[1]['SourceTrace']
      end

      AppOpticsAPM::SDK.start_trace(:'sidekiq-worker', nil, report_kvs) do
        yield
      end
    end
  end
end

if defined?(Sidekiq) && AppOpticsAPM::Config[:sidekiqworker][:enabled]
  AppOpticsAPM.logger.info '[appoptics_apm/loading] Instrumenting sidekiq worker' if AppOpticsAPM::Config[:verbose]

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      AppOpticsAPM.logger.info '[appoptics_apm/loading] Adding Sidekiq worker middleware' if AppOpticsAPM::Config[:verbose]
      chain.add AppOpticsAPM::SidekiqWorker
    end
  end
end
