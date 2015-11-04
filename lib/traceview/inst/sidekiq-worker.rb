module TraceView
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
        report_kvs[:Args]       = msg['args'].to_s[0..1024] if TV::Config[:sidekiqworker][:log_args]
        report_kvs['Backtrace'] = TV::API.backtrace         if TV::Config[:sidekiqworker][:collect_backtraces]

        # Webserver Spec KVs
        report_kvs['HTTP-Host'] = Socket.gethostname
        report_kvs[:Controller] = "Sidekiq_#{queue}"
        report_kvs[:Action] = msg['class']
        report_kvs[:URL] = "/sidekiq/#{queue}/#{msg['class']}"
      rescue => e
        TraceView.logger.warn "[traceview/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker, 1: msg, 2: queue
      report_kvs = collect_kvs(args)

      # Continue the trace from the enqueue side?
      if args[1].is_a?(Hash) && TraceView::XTrace.valid?(args[1]['SourceTrace'])
        report_kvs[:SourceTrace] = args[1]['SourceTrace']

        # Pass the source trace in the TV-Meta flag field to indicate tracing
        report_kvs['X-TV-Meta'] = args[1]['SourceTrace']
      end

      result = TraceView::API.start_trace('sidekiq-worker', nil, report_kvs) do
        yield
      end

      result[0]
    end
  end
end

if defined?(::Sidekiq) && RUBY_VERSION >= '2.0' && TraceView::Config[:sidekiqworker][:enabled]
  ::TraceView.logger.info '[traceview/loading] Instrumenting sidekiq' if TraceView::Config[:verbose]

  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      ::TraceView.logger.info '[traceview/loading] Adding Sidekiq worker middleware' if TraceView::Config[:verbose]
      chain.add ::TraceView::SidekiqWorker
    end
  end
end
