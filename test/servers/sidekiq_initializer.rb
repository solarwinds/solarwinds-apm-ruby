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
ENV["TRACEVIEW_GEM_TEST"] = "true"
ENV["TRACEVIEW_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure TraceView
TraceView::Config[:tracing_mode] = "always"
TraceView::Config[:sample_rate] = 1000000
TraceView.logger.level = Logger::DEBUG

