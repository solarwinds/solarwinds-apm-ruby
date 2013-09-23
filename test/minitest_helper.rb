require "minitest/autorun"
require "minitest/reporters"

ENV["RACK_ENV"] = "test"
MiniTest::Reporters.use!

require 'rubygems'
require 'bundler'

Bundler.require(:default, :test)

# Preload memcache-client
require 'memcache'

$trace_file = File.dirname(__FILE__) + "/../tmp/trace_output.bson"

# Configure Oboe
Oboe::Config[:tracing_mode] = "always"
Oboe::Config[:sample_rate] = 1000000
Oboe::Ruby.initialize

##
# clear_all_traces
#
# Truncates the trace output file to zero
#
def clear_all_traces
  File.truncate($trace_file, 0)
end

##
# get_all_traces
#
# Retrieves all traces written to the trace file
#
def get_all_traces
  traces = []
  f = File.open($trace_file)
  until f.eof?
    traces << BSON.read_bson_document(f)
  end
  traces
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

