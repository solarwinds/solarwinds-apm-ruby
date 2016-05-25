workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  ::TraceView.reconnect! if defined?(::TraceView)
end

on_worker_shutdown do
  ::TraceView.disconnect! if defined?(::TraceView)
end
