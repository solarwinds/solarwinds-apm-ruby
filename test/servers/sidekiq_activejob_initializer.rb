# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# This file is used to initialize the background Sidekiq
# process launched in our test suite.

ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"


require 'rubygems'
require 'bundler/setup'
require 'solarwinds_apm'

require_relative '../jobs/sidekiq/activejob_worker_job.rb'

ENV["RACK_ENV"] = "test"
ENV["SW_AMP_GEM_TEST"] = "true"
ENV["SW_AMP_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure SolarWindsAPM
SolarWindsAPM::Config[:tracing_mode] = :enabled
SolarWindsAPM::Config[:sample_rate] = 1000000
# SolarWindsAPM.logger.level = Logger::DEBUG
SolarWindsAPM.logger.level = Logger::FATAL
