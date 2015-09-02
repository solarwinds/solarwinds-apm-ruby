ENV['BUNDLE_GEMFILE'] = Dir.pwd + "gemfiles/libraries.gemfile"

require 'rubygems'
require 'bundler/setup'

ENV["RACK_ENV"] = "test"
ENV["TRACEVIEW_GEM_TEST"] = "true"
ENV["TRACEVIEW_GEM_VERBOSE"] = "true"

Bundler.require(:default, :test)

# Configure TraceView
TraceView::Config[:verbose] = true
TraceView::Config[:tracing_mode] = "always"
TraceView::Config[:sample_rate] = 1000000
TraceView.logger.level = Logger::DEBUG

