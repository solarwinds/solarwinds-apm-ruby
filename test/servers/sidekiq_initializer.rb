# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This file is used to initialize the background Sidekiq
# process launched in our test suite.
#
ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"

require 'rubygems'
require 'bundler/setup'
require_relative '../jobs/sidekiq/db_worker_job'
require_relative '../jobs/sidekiq/remote_call_worker_job'
require_relative '../jobs/sidekiq/error_worker_job'

ENV["RACK_ENV"] = "test"
ENV["APPOPTICS_GEM_TEST"] = "true"
ENV["APPOPTICS_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure AppOptics
AppOptics::Config[:tracing_mode] = "always"
AppOptics::Config[:sample_rate] = 1000000
AppOptics.logger.level = Logger::DEBUG

