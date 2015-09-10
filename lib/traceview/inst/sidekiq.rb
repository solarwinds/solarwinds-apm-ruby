module TraceView
  class SidekiqWorker
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.

        report_kvs = {}
        _, msg, queue = args

        report_kvs['Backtrace'] = TV::API.backtrace if TV::Config[:sidekiq][:collect_backtraces]

        # Background Job Spec KVs
        report_kvs[:Spec] = :job
        report_kvs[:JobName] = msg['class']
        report_kvs[:JobID] = msg['jid']
        report_kvs[:Source] = msg['queue']
        report_kvs[:Args] = msg['args'].to_s if TraceView::Config[:sidekiq][:log_args]

        # Webserver Spec KVs
        report_kvs['HTTP-Host'] = Socket.gethostname
        report_kvs[:Controller] = "Sidekiq_#{queue}"
        report_kvs[:Action] = msg['class']
        report_kvs[:URL] = "/sidekiq/#{args[2]}/#{args[1]['class'].to_s}"
      rescue => e
        TraceView.logger.warn "[traceview/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker, 1: msg, 2: queue

      result = nil
      report_kvs = collect_kvs(args)


      result = TraceView::API.start_trace('sidekiq-worker', nil, report_kvs) do
        yield
      end

      result[0]
    end
  end
end

if defined?(::Sidekiq) && RUBY_VERSION >= '2.0' && TraceView::Config[:sidekiq][:enabled]
  ::TraceView.logger.info '[traceview/loading] Instrumenting sidekiq' if TraceView::Config[:verbose]

  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      ::TraceView.logger.info '[traceview/loading] Adding Sidekiq worker middleware' if TraceView::Config[:verbose]
      chain.add ::TraceView::SidekiqWorker
    end
  end
end
