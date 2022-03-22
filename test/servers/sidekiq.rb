# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# We configure and launch Sidekiq in a background
# thread here.

require 'sidekiq/cli'

unless `ps -aef | grep 'sidekiq' | grep SW_APM_GEM_TEST | grep -v grep`.empty?
  SolarWindsAPM.logger.debug "[solarwinds_apm/servers] Killing old sidekiq process:#{`ps aux | grep [s]idekiq`}."
  cmd = "pkill -9 -f sidekiq"
  `#{cmd}`
  sleep 1
end


SolarWindsAPM.logger.info "[solarwinds_apm/servers] Starting up background Sidekiq."

options = []
arguments = ""
options << ["-r", Dir.pwd + "/test/servers/sidekiq_initializer.rb"]
options << ["-q", "critical,20", "-q", "default"]
options << ["-c", "10"]
# options << ["-P", "/tmp/sidekiq_#{Process.pid}.pid"]

options.flatten.each do |x|
  arguments += " #{x}"
end

SolarWindsAPM.logger.debug "[solarwinds_apm/servers] sidekiq #{arguments}"

Thread.new do
  system("SW_APM_GEM_TEST=true sidekiq #{arguments}")
end

# Allow Sidekiq to boot up
sleep 10
