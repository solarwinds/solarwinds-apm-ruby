if RUBY_VERSION >= '1.9.3'
  require 'minitest_helper'
  require File.expand_path(File.dirname(__FILE__) + '/apps/grape_simple')

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
      traces.count.must_equal 4

      validate_outer_layers(traces, 'rack')

      traces[1]['Layer'].must_equal "grape"
      traces[2]['Layer'].must_equal "grape"
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
      traces[3]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.headers.key?('X-Trace').must_equal true
      r.headers['X-Trace'].must_equal traces[3]['X-Trace']
    end

    it "should trace a request with an exception" do
      @app = GrapeSimple

      begin
        r = get "/break"
      rescue Exception => e
        # Do not handle/raise this error so
        # we can continue to test
      end

      traces = get_all_traces
      traces.count.must_equal 5

      validate_outer_layers(traces, 'rack')

      traces[1]['Layer'].must_equal "grape"
      traces[2]['Layer'].must_equal "grape"
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
      traces[3]['Label'].must_equal "error"
      traces[3]['ErrorClass'].must_equal "Exception"
      traces[3]['ErrorMsg'].must_equal "This should have http status code 500!"
      traces[4]['Label'].must_equal "exit"
    end

    it "should trace a request with an error" do
      @app = GrapeSimple

      r = get "/error"

      traces = get_all_traces
      traces.count.must_equal 5

      r.status.must_equal 500
      r.headers.key?('X-Trace').must_equal true

      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[1]['Layer'].must_equal "grape"
      traces[2]['Layer'].must_equal "grape"
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
      traces[3]['Label'].must_equal "error"
      traces[3]['ErrorClass'].must_equal "GrapeError"
      traces[3]['ErrorMsg'].must_equal "This is a error with 'error'!"
      traces[4]['Layer'].must_equal "rack"
      traces[4]['Label'].must_equal "exit"
      traces[4]['Status'].must_equal "500"
    end
  end
end
