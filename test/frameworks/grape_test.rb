# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

if RUBY_VERSION >= '1.9.3' and defined?(::Grape)
  require File.expand_path(File.dirname(__FILE__) + '/apps/grape_simple')
  require File.expand_path(File.dirname(__FILE__) + '/apps/grape_nested')

  describe Grape do
    before do
      clear_all_traces
    end

    it "should trace a request to a simple grape stack" do
      @app = GrapeSimple

      r = get "/json_endpoint"

      r.status.must_equal 200
      r.headers.key?('X-Trace').must_equal true

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "grape"
      traces[3]['Layer'].must_equal "grape"
      traces[3].has_key?('Controller').must_equal true
      traces[3].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.headers.key?('X-Trace').must_equal true
      r.headers['X-Trace'].must_equal traces[4]['X-Trace']
    end

    it "should trace a request to a nested grape stack" do
      @app = GrapeNested

      r = get "/json_endpoint"

      r.status.must_equal 200
      r.headers.key?('X-Trace').must_equal true

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "grape"
      traces[3]['Layer'].must_equal "grape"
      traces[3].has_key?('Controller').must_equal true
      traces[3].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.headers.key?('X-Trace').must_equal true
      r.headers['X-Trace'].must_equal traces[4]['X-Trace']
    end

    it "should trace a an error in a nested grape stack" do
      @app = GrapeNested

      r = get "/error"

      r.status.must_equal 500
      r.headers.key?('X-Trace').must_equal true

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "grape"
      traces[2]['Label'].must_equal "entry"
      traces[3]['Layer'].must_equal "grape"
      traces[3]['Label'].must_equal "exit"
      traces[3].has_key?('Controller').must_equal true
      traces[3].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "error"
      traces[4]['ErrorClass'].must_equal "GrapeError"
      traces[4]['ErrorMsg'].must_equal "This is a error with 'error'!"
      traces[4].has_key?('Backtrace').must_equal true
      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.headers.key?('X-Trace').must_equal true
      r.headers['X-Trace'].must_equal traces[5]['X-Trace']
    end


    it "should trace a request with an exception" do
      @app = GrapeSimple

      begin
        get "/break"
      rescue Exception
        # Do not handle/raise this error so
        # we can continue to test
      end

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, 'rack')

      traces[2]['Layer'].must_equal "grape"
      traces[3]['Layer'].must_equal "grape"
      traces[3].has_key?('Controller').must_equal true
      traces[3].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "error"
      traces[4]['ErrorClass'].must_equal "Exception"
      traces[4]['ErrorMsg'].must_equal "This should have http status code 500!"
      traces[5]['Label'].must_equal "exit"
    end

    it "should trace a request with an error" do
      @app = GrapeSimple

      r = get "/error"

      traces = get_all_traces
      traces.count.must_equal 6

      r.status.must_equal 500
      r.headers.key?('X-Trace').must_equal true

      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[2]['Layer'].must_equal "grape"
      traces[3]['Layer'].must_equal "grape"
      traces[3].has_key?('Controller').must_equal true
      traces[3].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "error"
      traces[4]['ErrorClass'].must_equal "GrapeError"
      traces[4]['ErrorMsg'].must_equal "This is a error with 'error'!"
      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"
      traces[5]['Status'].must_equal 500
    end
  end
end
