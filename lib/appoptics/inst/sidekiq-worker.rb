# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
  class SidekiqWorker
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.
        report_kvs = {}
        worker, msg, queue = args

        # Background Job Spec KVs
        report_kvs[:Spec]       = :job
        report_kvs[:Flavor]     = :sidekiq
        report_kvs[:Queue]      = queue
        report_kvs[:Retry]      = msg['retry']
        report_kvs[:JobName]    = worker.class.to_s
        report_kvs[:MsgID]      = msg['jid']
        report_kvs[:Args]       = msg['args'].to_s[0..1024] if AppOptics::Config[:sidekiqworker][:log_args]
        report_kvs[:Backtrace]  = AppOptics::API.backtrace         if AppOptics::Config[:sidekiqworker][:collect_backtraces]

        # Webserver Spec KVs
        report_kvs[:'HTTP-Host'] = Socket.gethostname
        report_kvs[:Controller] = "Sidekiq_#{queue}"
        report_kvs[:Action] = msg['class']
        report_kvs[:URL] = "/sidekiq/#{queue}/#{msg['class']}"
      rescue => e
        AppOptics.logger.warn "[appoptics/sidekiq] Non-fatal error capturing KVs: #{e.message}"
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
      AppOptics::Config[:tracing_mode] = AppOptics::Config[:tracing_mode]

      # Continue the trace from the enqueue side?
      if args[1].is_a?(Hash) && AppOptics::XTrace.valid?(args[1]['SourceTrace'])
        report_kvs[:SourceTrace] = args[1]['SourceTrace']
      end

      result = AppOptics::API.start_trace(:'sidekiq-worker', nil, report_kvs) do
        yield
      end

      result[0]
    end
  end
end

if defined?(::Sidekiq) && RUBY_VERSION >= '2.0' && AppOptics::Config[:sidekiqworker][:enabled]
  ::AppOptics.logger.info '[appoptics/loading] Instrumenting sidekiq' if AppOptics::Config[:verbose]

  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      ::AppOptics.logger.info '[appoptics/loading] Adding Sidekiq worker middleware' if AppOptics::Config[:verbose]
      chain.add ::AppOptics::SidekiqWorker
    end
  end
end
