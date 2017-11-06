# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# We configure and launch Sidekiq in a background
# thread here.
#
require 'sidekiq/cli'

AppOptics.logger.info "[appoptics/servers] Starting up background Sidekiq."

options = []
arguments = ""
options << ["-r", Dir.pwd + "/test/servers/sidekiq_initializer.rb"]
options << ["-q", "critical,20", "-q", "default"]
options << ["-c", "10"]
options << ["-P", "/tmp/sidekiq_#{Process.pid}.pid"]

options.flatten.each do |x|
  arguments += " #{x}"
end

AppOptics.logger.debug "[appoptics/servers] sidekiq #{arguments}"

Thread.new do
  system("OBOE_GEM_TEST=true sidekiq #{arguments}")
end

# Allow Sidekiq to boot up
sleep 10
