# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This file is used to initialize the background Sidekiq
# process launched in our test suite.
#
ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"

Sidekiq.configure_server do |config|
  config.redis = { :password => ENV['REDIS_PASSWORD'] || 'secret_pass' }
  if ENV.key?('REDIS_HOST')
    config.redis << { :url => "redis://#{ENV['REDIS_HOST']}:6379" }
  end
end

require 'rubygems'
require 'bundler/setup'
require_relative '../jobs/sidekiq/db_worker_job'
require_relative '../jobs/sidekiq/remote_call_worker_job'
require_relative '../jobs/sidekiq/error_worker_job'

ENV["RACK_ENV"] = "test"
ENV["SW_AMP_GEM_TEST"] = "true"
# ENV["SW_AMP_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure SolarWindsAPM
SolarWindsAPM::Config[:tracing_mode] = :enabled
SolarWindsAPM::Config[:sample_rate] = 1000000
# SolarWindsAPM.logger.level = Logger::DEBUG
SolarWindsAPM.logger.level = Logger::FATAL

sleep 10
