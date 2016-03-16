# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'rubygems'
require 'bundler/setup'
require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']

require "minitest/hell"
class Minitest::Test
  # parallelize_me!
end

ENV["RACK_ENV"] = "test"
ENV["TRACEVIEW_GEM_TEST"] = "true"
ENV["TRACEVIEW_GEM_VERBOSE"] = "true"

# FIXME: Temp hack to fix padrino-core calling RUBY_ENGINE when it's
# not defined under Ruby 1.8.7 and 1.9.3
RUBY_ENGINE = "ruby" unless defined?(RUBY_ENGINE)

Minitest::Spec.new 'pry'

unless RUBY_VERSION =~ /^1.8/
  MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new
end

if defined?(JRUBY_VERSION)
  ENV['JAVA_OPTS'] = "-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar"
end

@trace_dir = "/tmp/"
$trace_file = @trace_dir + "trace_output.bson"

Bundler.require(:default, :test)

# Configure TraceView
TraceView::Config[:verbose] = true
TraceView::Config[:tracing_mode] = "always"
TraceView::Config[:sample_rate] = 1000000
TraceView.logger.level = Logger::DEBUG

# Pre-create test databases (see also .travis.yml)
# puts "Pre-creating test databases"
# puts %x{mysql -u root -e 'create database travis_ci_test;'}
# puts %x{psql -c 'create database travis_ci_test;' -U postgres}

# Our background Rack-app for http client testing
require './test/servers/rackapp_8101'

# Conditionally load other background servers
# depending on what we're testing
#
case File.basename(ENV['BUNDLE_GEMFILE'])
when /delayed_job/
  require './test/servers/delayed_job'

when /rails5/
  require './test/servers/rails5x_8140'

when /rails4/
  require './test/servers/rails4x_8140'

when /rails3/
  require './test/servers/rails3x_8140'

when /frameworks/
when /libraries/
  if RUBY_VERSION >= '2.0'
    # Load Sidekiq if TEST isn't defined or if it is, it calls
    # out the sidekiq tests
    if !ENV.key?('TEST') || ENV['TEST'] =~ /sidekiq/
      # Background Sidekiq thread
      require './test/servers/sidekiq.rb'
    end
  end
end

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  if TraceView.loaded
    TraceView::Reporter.clear_all_traces
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if TraceView.loaded
    TraceView::Reporter.get_all_traces
  else
    []
  end
end

##
# validate_outer_layers
#
# Validates that the KVs in kvs are present
# in event
#
def validate_outer_layers(traces, layer)
  traces.first['Layer'].must_equal layer
  traces.first['Label'].must_equal 'entry'
  traces.last['Layer'].must_equal layer
  traces.last['Label'].must_equal 'exit'
end

##
# validate_event_keys
#
# Validates that the KVs in kvs are present
# in event
#
def validate_event_keys(event, kvs)
  kvs.each do |k, v|
    assert_equal true, event.key?(k), "#{k} is missing"
    assert event[k] == v, "#{k} != #{v} (#{event[k]})"
  end
end

##
# has_edge?
#
# Searches the array of <tt>traces</tt> for
# <tt>edge</tt>
#
def has_edge?(edge, traces)
  traces.each do |t|
    if TraceView::XTrace.edge_id(t["X-Trace"]) == edge
      return true
    end
  end
  TraceView.logger.debug "[oboe/debug] edge #{edge} not found in traces."
  false
end

##
# valid_edges?
#
# Runs through the array of <tt>traces</tt> to validate
# that all edges connect.
#
# Not that this won't work for external cross-app tracing
# since we won't have those remote traces to validate
# against.
#
def valid_edges?(traces)
  traces.reverse.each do  |t|
    if t.key?("Edge")
      unless has_edge?(t["Edge"], traces)
        return false
      end
    end
  end
  true
end

##
# layer_has_key
#
# Checks an array of trace events if a specific layer (regardless of event type)
# has he specified key
#
def layer_has_key(traces, layer, key)
  return false if traces.empty?
  has_key = false

  traces.each do |t|
    if t["Layer"] == layer and t.has_key?(key)
      has_key = true

      (t["Backtrace"].length > 0).must_equal true
    end
  end

  has_key.must_equal true
end

##
# layer_doesnt_have_key
#
# Checks an array of trace events to assure that a specific layer
# (regardless of event type) doesn't have the specified key
#
def layer_doesnt_have_key(traces, layer, key)
  return false if traces.empty?
  has_key = false

  traces.each do |t|
    has_key = true if t["Layer"] == layer and t.has_key?(key)
  end

  has_key.must_equal false
end

if (File.basename(ENV['BUNDLE_GEMFILE']) =~ /^frameworks/) == 0
  require "sinatra"
  ##
  # Sinatra and Padrino Related Helpers
  #
  # Taken from padrino-core gem
  #
  class Sinatra::Base
    # Allow assertions in request context
    include MiniTest::Assertions
  end


  class MiniTest::Spec
    include Rack::Test::Methods

    # Sets up a Sinatra::Base subclass defined with the block
    # given. Used in setup or individual spec methods to establish
    # the application.
    def mock_app(base=Padrino::Application, &block)
      @app = Sinatra.new(base, &block)
    end

    def app
      Rack::Lint.new(@app)
    end
  end
end
