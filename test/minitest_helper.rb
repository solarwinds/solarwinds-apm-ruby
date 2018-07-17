# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'simplecov' if ENV["SIMPLECOV_COVERAGE"]
require 'simplecov-console' if ENV["SIMPLECOV_COVERAGE"]

SimpleCov.start do
# SimpleCov.formatter = SimpleCov.formatter = SimpleCov::Formatter::Console
  merge_timeout 3600
  command_name "#{RUBY_VERSION}_#{File.basename(ENV['BUNDLE_GEMFILE'])}_#{ENV['DBTYPE']}"
# SimpleCov.use_merging true
  add_filter '/test/'
  add_filter '../test/'
  use_merging true
end  if ENV["SIMPLECOV_COVERAGE"]

require 'rubygems'
require 'bundler/setup'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/debugger' if ENV['DEBUG']

if ENV['TEST_RUNS_TO_FILE']
# write to STDOUT as well as file (comes in handy with docker runs)
# this approach preserves the coloring of pass fail, which the cli
# `./run_tests.sh 2>&1 | tee -a test/docker_test.log` does not
  FileUtils.mkdir_p('log')  # create if it doesn't exist
  $out_file = File.new("log/test_runs_#{Time.now.strftime("%Y_%m_%d")}.log", 'a')
  $out_file.sync = true
  $stdout.sync = true
  def $stdout.write string
    $out_file.write string
    super
  end
end

puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']} #{Time.now.strftime("%Y-%m-%d %H:%M")} ===\033[0m\n"

ENV['RACK_ENV'] = 'test'
ENV['APPOPTICS_GEM_TEST'] = 'true'
# ENV['APPOPTICS_GEM_VERBOSE'] = 'true'

Minitest::Spec.new 'pry'

MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new

if defined?(JRUBY_VERSION)
  ENV['JAVA_OPTS'] = "-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar"
end

Bundler.require(:default, :test)

# Configure AppOpticsAPM
AppOpticsAPM::Config[:verbose] = true
AppOpticsAPM::Config[:tracing_mode] = "always"
AppOpticsAPM::Config[:sample_rate] = 1000000
# AppOpticsAPM.logger.level = Logger::DEBUG

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
  require './test/servers/rails5x_api_8150'

when /rails4/
  require './test/servers/rails4x_8140'

when /rails3/
  require './test/servers/rails3x_8140'

when /frameworks/
when /libraries/
  require 'rack/test'
  # Load Sidekiq if TEST isn't defined or if it is, it calls
  # out the sidekiq tests
  if !ENV.key?('TEST') || ENV['TEST'] =~ /sidekiq/
    # Background Sidekiq thread
    require './test/servers/sidekiq.rb'
  end
end

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  if AppOpticsAPM.loaded
    AppOpticsAPM::Context.clear
    AppOpticsAPM::Reporter.clear_all_traces
    sleep 0.2 # it seems like the docker file system needs a bit of time to clear the file
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if AppOpticsAPM.loaded
    AppOpticsAPM::Reporter.get_all_traces
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
    if AppOpticsAPM::XTrace.edge_id(t["X-Trace"]) == edge
      return true
    end
  end
  AppOpticsAPM.logger.debug "[oboe/debug] edge #{edge} not found in traces."
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

##
# Checks if the transaction name corresponds to Controller.Action
# if there are multiple events with Controller and/or Action, then they all have to match
#
def assert_controller_action(test_action)
  traces = get_all_traces
  traces.select { |tr| tr['Controller'] || tr['Action'] }.map do |tr|
    assert_equal(test_action, [tr['Controller'], tr['Action']].join('.'))
  end
end

def not_sampled?(xtrace)
  xtrace[59].to_i & 1 == 0
end

def sampled?(xtrace)
  xtrace[59].to_i & 1 == 1
end

def print_traces(traces, more_keys = [])
  indent = ''
  traces.each do |trace|
    indent += '  ' if trace["Label"] == "entry"

    puts "#{indent}X-Trace: #{trace["X-Trace"]}"
    puts "#{indent}Label:   #{trace["Label"]}"
    puts "#{indent}Layer:   #{trace["Layer"]}"

    more_keys.each { |key| puts "#{indent}#{key}:   #{trace[key]}"}

    indent = indent[0...-2] if trace["Label"] == "exit"
  end
  nil
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
