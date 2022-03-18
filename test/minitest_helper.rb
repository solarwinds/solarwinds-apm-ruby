# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'simplecov' if ENV["SIMPLECOV_COVERAGE"]
require 'simplecov-console' if ENV["SIMPLECOV_COVERAGE"]

SimpleCov.start do
# SimpleCov.formatter = SimpleCov.formatter = SimpleCov::Formatter::Console
  merge_timeout 3600
  command_name "#{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']}"
# SimpleCov.use_merging true
  add_filter '/test/'
  add_filter '../test/'
  use_merging true
end if ENV["SIMPLECOV_COVERAGE"]

require 'rubygems'
require 'bundler/setup'
require 'fileutils'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest'
require 'minitest/focus'
require 'minitest/debugger' if ENV['DEBUG']
require 'minitest/hooks/default'  # adds after(:all)

# write to a file as well as STDOUT (comes in handy with docker runs)
# This approach preserves the coloring of pass fail, which the cli
# `./run_tests.sh 2>&1 | tee -a test/docker_test.log` does not
if ENV['TEST_RUNS_TO_FILE']
  FileUtils.mkdir_p('log') # create if it doesn't exist
  if ENV['TEST_RUNS_FILE_NAME']
    $out_file = File.new(ENV['TEST_RUNS_FILE_NAME'], 'a')
  else
    $out_file = File.new("log/test_direct_runs_#{Time.now.strftime("%Y%m%d_%H_%M")}.log", 'a')
  end
  $out_file.sync = true
  $stdout.sync = true

  def $stdout.write(string)
    $out_file.write(string)
    super
  end
end

# Extend Minitest with a refute_raises method
# There are debates whether or not such a method is needed,
# because the test would fail anyways when an exception is raised
#
# The reason to have and use it is for the statistics. The count of
# assertions, failures, and errors is less informative without refute_raises
module MiniTest
  module Assertions
    def refute_raises *exp
      msg = "#{exp.pop}.\n" if String === exp.last

      begin
        yield
      rescue MiniTest::Skip => e
        return e if exp.include? MiniTest::Skip
        raise e
      rescue Exception => e
        exp = exp.first if exp.size == 1
        flunk "unexpected exception raised: #{e}"
      end

    end
  end
end

# Print out a headline in with the settings used in the test run
puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(ENV['BUNDLE_GEMFILE'])} #{ENV['DBTYPE']} #{ENV['TEST_PREPARED_STATEMENT']} #{Time.now.strftime("%Y-%m-%d %H:%M")} ===\033[0m\n"

ENV['RACK_ENV'] = 'test'
# The following should be set in docker, so that tests can use different reporters
# ENV['APPOPTICS_REPORTER'] = 'file'
# ENV['APPOPTICS_COLLECTOR'] = '/tmp/appoptics_traces.bson'.freeze
# ENV['APPOPTICS_REPORTER_FILE_SINGLE'] = 'false'
# ENV['APPOPTICS_GEM_TEST'] = 'true'

# ENV['APPOPTICS_GEM_VERBOSE'] = 'true' # currently redundant as we are setting AppOpticsAPM::Config[:verbose] = true

MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new

if defined?(JRUBY_VERSION)
  ENV['JAVA_OPTS'] = "-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar"
end

Bundler.require(:default, :test)

# Configure AppOpticsAPM
AppOpticsAPM::Config[:verbose] = true
AppOpticsAPM::Config[:tracing_mode] = :enabled
AppOpticsAPM::Config[:sample_rate] = 1000000
# AppOpticsAPM.logger.level = Logger::DEBUG

# Pre-create test databases (see also .travis.yml)
# puts "Pre-creating test databases"
# puts %x{mysql -u root -e 'create database test_db;'}
# puts %x{psql -c 'create database test_db;' -U postgres}

# Our background Rack-app for http client testing
if ENV['BUNDLE_GEMFILE'] && File.basename(ENV['BUNDLE_GEMFILE']) =~ /libraries|frameworks|instrumentation|noop/
  require './test/servers/rackapp_8101'
end
#
# # Conditionally load other background servers
# # depending on what we're testing
# #
case File.basename(ENV['BUNDLE_GEMFILE'])
when /delayed_job/
  require './test/servers/delayed_job'
when /rails/
  require './test/servers/rails5x_8140'
when /frameworks/
when /libraries/
  # Load Sidekiq for libaries tests
  # use `export NO_SIDEKIQ=true` to stop sidekiq from loading
  # when running individual test files
  # starting sidekiq slows down the startup and doesn't shut down properly
  unless (ENV.key?('TEST') && ENV['TEST'] =~ /sidekiq/) || (/benchmark/ =~ $0) || ENV['NO_SIDEKIQ']
    require './test/servers/sidekiq.rb'
  end
end

# Attempt to clean up the sidekiq processes at the end of tests
MiniTest.after_run do
  # for general Linux
    AppOpticsAPM.logger.debug "[appoptics_apm/servers] Killing old sidekiq process:#{`ps aux | grep [s]idekiq`}."
    cmd = "pkill -9 -f sidekiq"
    `#{cmd}`
end

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces(clear_context = true)
  if AppOpticsAPM.loaded && ENV['APPOPTICS_REPORTER'] == 'file'
    AppOpticsAPM::Context.clear if clear_context
    AppOpticsAPM::Reporter.clear_all_traces
    AppOpticsAPM.trace_context = nil
    sleep 0.2 # it seems like the docker file system needs a bit of time to clear the file
  end
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  if AppOpticsAPM.loaded && ENV['APPOPTICS_REPORTER'] == 'file'
    sleep 0.5
    AppOpticsAPM::Reporter.get_all_traces
  else
    []
  end
end

##
# read the ActiveRecord logfile and match it with regex
# use case: test if trace-id has been injected in query
#
# `clear_query_log` before next test
def query_logged?(regex)
  File.open(ENV['QUERY_LOG_FILE']).read() =~ regex
end

def print_query_log
  puts File.open(ENV['QUERY_LOG_FILE']).read()
end

##
# clear the ActiveRecord logfile, but don't remove it
# create if it doesn't exist
#
def clear_query_log
  ENV['QUERY_LOG_FILE'] ||= '/tmp/query_log.txt'
  if File.exist?(ENV['QUERY_LOG_FILE'])
    File.truncate(ENV['QUERY_LOG_FILE'], 0)
  else
    FileUtils.touch(ENV['QUERY_LOG_FILE'])
  end
end

##
# validate_outer_layers
#
# Validates that the KVs in kvs are present
# in event
#
def validate_outer_layers(traces, layer)
  _(traces.first['Layer']).must_equal layer
  _(traces.first['Label']).must_equal 'entry'
  _(traces.last['Layer']).must_equal layer
  _(traces.last['Label']).must_equal 'exit'
end

##
# validate_event_keys
#
# Validates that the KVs in kvs are present
# in event
#
def validate_event_keys(event, kvs)
  kvs.each do |k, v|
    assert event.key?(k), "#{k} is missing"
    assert_equal event[k], v, "#{k} != #{v} (#{event[k]})"
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
    if AppOpticsAPM::TraceString.span_id(t["sw.trace_context"]) == edge
      return true
    end
  end
  AppOpticsAPM.logger.debug "[appoptics_apm/test] edge #{edge} not found in traces."
  false
end

def assert_entry_exit(traces, num = nil, check_trace_id = true)
  if check_trace_id
    trace_id = AppOpticsAPM::TraceString.trace_id(traces[0]['sw.trace_context'])
    refute traces.find { |tr| AppOpticsAPM::TraceString.trace_id(tr['sw.trace_context']) != trace_id }, "trace ids not matching"
  end
  num_entries = traces.select { |tr| tr ['Label'] == 'entry' }.size
  num_exits = traces.select { |tr| tr ['Label'] == 'exit' }.size
  if num && num > 0
    _(num_entries).must_equal num, "incorrect number of entry spans"
    _(num_exits).must_equal num, "incorrect number of exit spans"
  else
    _(num_exits).must_equal num_entries, "number of exit spans is not the same as entry spans"
  end
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
# The param connected can be set to false if there are disconnected traces
#
def valid_edges?(traces, connected = true)
  return true unless traces.is_a?(Array) && traces.count > 1 # so that in case the traces are sent to the collector, tests will fail but not barf
  traces[1..-1].reverse.each do |t|
    if t.key?("sw.parent_span_id")
      unless has_edge?(t["sw.parent_span_id"], traces)
        puts "edge missing for #{t["sw.parent_span_id"]}"
        # TODO NH-2303 maybe remove when done
        print_traces(traces[1..-1])
        return false
      end
    end
  end
  if connected
    if traces.map { |tr| tr['sw.parent_span_id'] }.uniq.size == traces.size
      return true
    else
      # TODO NH-2303 maybe remove when done
      puts "number of unique sw.parent_span_ids: #{traces.map { |tr| tr['sw.parent_span_id'] }.uniq.size}"
      puts "number of traces: traces.size"
      print_traces(traces)
      return false
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

      _(t[key].length > 0).must_equal true
    end
  end

  _(has_key).must_equal true
end

##
# layer_has_key
#
# Checks an array of trace events if a specific layer (regardless of event type)
# has he specified key
#
def layer_has_key_once(traces, layer, key)
  return false if traces.empty?
  has_keys = 0

  traces.each do |t|
    has_keys += 1 if t["Layer"] == layer and t.has_key?(key)
  end

  _(has_keys).must_equal 1, "Key #{key} missing in layer #{layer}"
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

  _(has_key).must_equal false, "Key #{key} should not be in layer #{layer}"
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

def not_sampled?(tracestring)
  !sampled?(tracestring)
end

def sampled?(tracestring)
  AppOpticsAPM::TraceString.sampled?(tracestring)
end

#########################            ###            ###            ###            ###            ###
### DEBUGGING HELPERS ###
#########################

def pretty(traces)
  puts traces.pretty_inspect
end

def print_traces(traces, more_keys = [])
  return unless traces.is_a?(Array) # so that in case the traces are sent to the collector, tests will fail but not barf
  indent = ''
  puts "\n"
  traces.each do |trace|
    indent += '  ' if trace["Label"] == "entry"

    puts "#{indent}Label:   #{trace["Label"]}"
    puts "#{indent}Layer:   #{trace["Layer"]}"
    puts "#{indent}sw.trace_context: #{trace["sw.trace_context"]}"
    puts "#{indent}sw.parent_span_id: #{trace["sw.parent_span_id"]}"

    more_keys.each { |key| puts "#{indent}#{key}:   #{trace[key]}" if trace[key] }

    indent = indent[0...-2] if trace["Label"] == "exit"
  end
  puts "\n"
end

def print_edges(traces)
  traces.each do |trace|
    puts "EVENT: Edge: #{trace['Edge']} (#{trace['Label']}) \nnext Edge: #{trace['X-Trace'][42..-3]}\n"
  end
end

# Ruby 2.4 doesn't have the transform_keys method
unless Hash.instance_methods.include?(:transform_keys)
  class Hash
    def transform_keys
      new_hash = {}
      self.each do |k, v|
        new_hash[yield(k)] = v
      end
      new_hash
    end
  end
end

# this checks if `sw=...` is at the beginning of tracestate and returns the value
def sw_tracestate(tracestate)
  matches = /^[,\s]*sw=(?<sw_value>[a-f0-9]{16}-0[01])/.match(tracestate)
  matches && matches[:sw_value]
end

# this extracts the sw value anywhere within tracestate
def sw_value(tracestate)
  matches = /[,\s]*sw=(?<sw_value>[a-f0-9]{16}-0[01])/.match(tracestate)
  matches && matches[:sw_value]
end

def assert_trace_headers(headers, sampled = nil)
  # don't use transform_keys! (the one with the bang!)
  # it makes follow up assertions fail
  # and it is not available in Ruby 2.4
  headers = headers.transform_keys(&:downcase)
  assert headers['traceparent'], "traceparent header missing"
  assert AppOpticsAPM::TraceString.valid?(headers['traceparent']), "traceparent header not valid"
  assert AppOpticsAPM::TraceString.sampled?(headers['traceparent']), "traceparent should have sampled flag" if sampled
  refute AppOpticsAPM::TraceString.sampled?(headers['traceparent']), "traceparent should NOT have sampled flag" if sampled == false

  assert headers['tracestate'], "tracestate header missing"
  assert_match /#{APPOPTICS_TRACESTATE_ID}=/, headers['tracestate'], "tracestate header missing #{APPOPTICS_TRACESTATE_ID}"

  assert sw_tracestate(headers['tracestate']), "tracestate header not starting with correct sw member"
  assert_equal AppOpticsAPM::TraceString.span_id_flags(headers['traceparent']),
               sw_value(headers['tracestate']), "edge_id and flags not matching"
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
    def mock_app(base = Padrino::Application, &block)
      @app = Sinatra.new(base, &block)
    end

    def app
      Rack::Lint.new(@app)
    end
  end
end
