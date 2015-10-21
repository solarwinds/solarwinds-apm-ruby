# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

ENV['BUNDLE_GEMFILE'] = Dir.pwd + "/gemfiles/libraries.gemfile"

require 'rubygems'
require 'bundler/setup'
require_relative '../jobs/db_worker_job'
require_relative '../jobs/remote_call_worker_job'
require_relative '../jobs/error_worker_job'

ENV["RACK_ENV"] = "test"
ENV["TRACEVIEW_GEM_TEST"] = "true"
ENV["TRACEVIEW_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure TraceView
TraceView::Config[:tracing_mode] = "always"
TraceView::Config[:sample_rate] = 1000000
TraceView.logger.level = Logger::DEBUG

