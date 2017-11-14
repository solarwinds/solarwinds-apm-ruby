# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOptics
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
        report_kvs[:JobName]   = worker_class
        report_kvs[:MsgID]     = msg['jid']
        report_kvs[:Args]      = msg['args'].to_s[0..1024] if AppOptics::Config[:sidekiqclient][:log_args]
        report_kvs[:Backtrace] = AppOptics::API.backtrace         if AppOptics::Config[:sidekiqclient][:collect_backtraces]
      rescue => e
        AppOptics.logger.warn "[appoptics/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker_class, 1: msg, 2: queue, 3: redis_pool
      report_kvs = collect_kvs(args)

      AppOptics::API.log_entry(:'sidekiq-client', report_kvs)
      args[1]['SourceTrace'] = AppOptics::Context.toString if AppOptics.tracing?

      result = yield

      report_kvs = { :JobID => result['jid'] }
      result
    rescue => e
      AppOptics::API.log_exception(:'sidekiq-client', e, report_kvs)
      raise
    ensure
      AppOptics::API.log_exit(:'sidekiq-client', report_kvs)
    end
  end
end

if defined?(::Sidekiq) && RUBY_VERSION >= '2.0' && AppOptics::Config[:sidekiqclient][:enabled]
  ::Sidekiq.configure_client do |config|
    config.client_middleware do |chain|
      ::AppOptics.logger.info '[appoptics/loading] Adding Sidekiq client middleware' if AppOptics::Config[:verbose]
      chain.add ::AppOptics::SidekiqClient
    end
  end
end
