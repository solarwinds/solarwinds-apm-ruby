require 'sidekiq/cli'

TraceView.logger.info "[traceview/servers] Starting up background Sidekiq."

Thread.new do
  cli = ::Sidekiq::CLI.instance
  options = []
  options << ["-r", Dir.pwd + "/test/jobs/db_worker_job.rb"]
  options << ["-r", Dir.pwd + "/test/jobs/remote_call_worker_job.rb"]
  options << ["-c", "2"]
  options << ["-q", "critical,2", "-q", "default"]
  options << ["-P", "/tmp/sidekiq_#{Process.pid}..pid"]
  cli.parse(options.flatten)

  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      ::TraceView.logger.info '[traceview/loading] Adding Sidekiq worker middleware' if TraceView::Config[:verbose]
      chain.add ::TraceView::SidekiqWorker
    end
  end

  cli.run
end
