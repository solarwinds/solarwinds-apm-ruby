module TraceView
  class SidekiqClient
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.

        report_kvs = {}
        _, msg, queue = args

        report_kvs['Backtrace'] = TV::API.backtrace if TV::Config[:sidekiq][:collect_backtraces]
      rescue => e
        TraceView.logger.warn "[traceview/sidekiq] Non-fatal error capturing KVs: #{e.message}"
      end
      report_kvs
    end

    def call(*args)
      # args: 0: worker_class, 1: msg, 2: queue, 3: redis_pool

      result = nil
      report_kvs = collect_kvs(args)

      result = TraceView::API.start_trace('sidekiq-client', nil, report_kvs) do
        yield
      end

      result[0]
    end
  end
end

if defined?(::Sidekiq) && RUBY_VERSION >= '2.0' && TraceView::Config[:sidekiq][:enabled]
  ::Sidekiq.configure_client do |config|
    config.client_middleware do |chain|
      ::TraceView.logger.info '[traceview/loading] Adding Sidekiq client middleware' if TraceView::Config[:verbose]
      chain.add ::TraceView::SidekiqClient
    end
  end
end
