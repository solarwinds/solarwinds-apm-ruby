# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This file is used to initialize the background Sidekiq
# process launched in our test suite.

ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"


require 'rubygems'
require 'bundler/setup'
require 'appoptics_apm'

require_relative '../jobs/sidekiq/activejob_worker_job.rb'

ENV["RACK_ENV"] = "test"
ENV["APPOPTICS_GEM_TEST"] = "true"
ENV["APPOPTICS_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure AppOpticsAPM
AppOpticsAPM::Config[:tracing_mode] = "always"
AppOpticsAPM::Config[:sample_rate] = 1000000
# AppOpticsAPM.logger.level = Logger::DEBUG

