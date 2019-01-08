# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# We configure and launch Sidekiq in a background
# thread here.
#
require 'sidekiq/cli'

AppOpticsAPM.logger.info "[appoptics_apm/servers] Starting up background Sidekiq."

options = []
arguments = ""
options << ["-r", Dir.pwd + "/test/servers/sidekiq_initializer.rb"]
options << ["-q", "critical,20", "-q", "default"]
options << ["-c", "10"]
options << ["-P", "/tmp/sidekiq_#{Process.pid}.pid"]

options.flatten.each do |x|
  arguments += " #{x}"
end

AppOpticsAPM.logger.debug "[appoptics_apm/servers] sidekiq #{arguments}"

Thread.new do
  system("APPOPTICS_GEM_TEST=true sidekiq #{arguments}")
  # system("sidekiq #{arguments}")
end

# Allow Sidekiq to boot up
sleep 10
