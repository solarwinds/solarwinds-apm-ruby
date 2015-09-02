require 'sidekiq/cli'

TraceView.logger.info "[traceview/servers] Starting up background Sidekiq."

options = []
arguments = ""
options << ["-r", Dir.pwd + "/test/jobs/job_initializer.rb"]
options << ["-c", "2"]
options << ["-q", "critical,2", "-q", "default"]
options << ["-P", "/tmp/sidekiq_#{Process.pid}.pid"]

options.flatten.each do |x|
  arguments += " #{x}"
end

TraceView.logger.debug "[traceview/servers] sidekiq #{arguments}"

# Boot Sidekiq in a new thread
Thread.new do
  system("OBOE_GEM_TEST=true sidekiq #{arguments}")
end

# Allow Sidekiq to boot up
sleep 2

# Add a hook to shutdown sidekiq after Minitest finished running
Minitest.after_run {
  TraceView.logger.warn "[traceview/servers] Shutting down Sidekiq. (pid: #{@sidekiq_pid})"
  pid = File.read("/tmp/sidekiq_#{Process.pid}.pid").chomp
  Process.kill(:TERM, pid.to_i)
}
