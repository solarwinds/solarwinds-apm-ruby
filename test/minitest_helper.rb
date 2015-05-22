require "minitest/spec"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/debugger" if ENV['DEBUG']

ENV["RACK_ENV"] = "test"
ENV["TRACEVIEW_GEM_TEST"] = "true"

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

require 'rubygems'
require 'bundler'

# Preload memcache-client
require 'memcache'

Bundler.require(:default, :test)

@trace_dir = "/tmp/"
$trace_file = @trace_dir + "trace_output.bson"

# Configure TraceView
TraceView::Config[:verbose] = true
TraceView::Config[:tracing_mode] = "always"
TraceView::Config[:sample_rate] = 1000000
TraceView.logger.level = Logger::DEBUG

# Our background Rack-app for http client testing
require "./test/servers/rackapp_8101"

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  TraceView::Reporter.clear_all_traces
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  TraceView::Reporter.get_all_traces
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
    event.has_key?(k).must_equal true
    event[k].must_equal v
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
      return false unless has_edge?(t["Edge"], traces)
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

