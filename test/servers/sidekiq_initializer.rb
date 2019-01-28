# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This file is used to initialize the background Sidekiq
# process launched in our test suite.
#
ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"

Sidekiq.configure_server do |config|
  config.redis = { :password => 'secret_pass' }
end

require 'rubygems'
require 'bundler/setup'
require_relative '../jobs/sidekiq/db_worker_job'
require_relative '../jobs/sidekiq/remote_call_worker_job'
require_relative '../jobs/sidekiq/error_worker_job'

ENV["RACK_ENV"] = "test"
ENV["APPOPTICS_GEM_TEST"] = "true"
# ENV["APPOPTICS_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure AppOpticsAPM
AppOpticsAPM::Config[:tracing_mode] = "always"
AppOpticsAPM::Config[:sample_rate] = 1000000
# AppOpticsAPM.logger.level = Logger::DEBUG
AppOpticsAPM.logger.level = Logger::FATAL
