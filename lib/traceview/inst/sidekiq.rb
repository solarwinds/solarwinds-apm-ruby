module TraceView
  class SidekiqWorker
    def collect_kvs(args)
      begin
        # Attempt to collect up pertinent info.  If we hit something unexpected,
        # keep calm and instrument on.

        report_kvs = {}
        report_kvs['Backtrace'] = TV::API.backtrace if TV::Config[:sidekiq][:collect_backtraces]
        report_kvs[:Op] = :perform
        report_kvs['HTTP-Host'] = Socket.gethostname
        report_kvs[:Method] = 'Worker'

        if args.is_a?(Array) && args.count == 3
          report_kvs['Args'] = args.to_s if TV::Config[:sidekiq][:log_args] && !args.empty?
          report_kvs[:Controller] = "Sidekiq_#{args[2]}"
          report_kvs[:Action] = args[1]['class'].to_s

          report_kvs[:URL] = "/sidekiq/#{args[2]}/#{args[1]['class'].to_s}"
          report_kvs[:Queue] = args[2].to_s

          if TraceView::Config[:sidekiq][:log_args]
            kv_args = args[1]['args'].to_s

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end
        end
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
