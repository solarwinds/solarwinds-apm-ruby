# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

if defined?(::Grape)
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
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
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
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
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
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
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
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
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
      traces[2].has_key?('Controller').must_equal true
      traces[2].has_key?('Action').must_equal true
      traces[4]['Label'].must_equal "error"
      traces[4]['ErrorClass'].must_equal "GrapeError"
      traces[4]['ErrorMsg'].must_equal "This is an error with 'error'!"
      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"
      traces[5]['Status'].must_equal 500
    end

    it "should report a simple GET path" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      get "/employee_data"

      assert_equal "GrapeSimple./employee_data", test_action
      assert_equal "http://example.org/employee_data", test_url
      assert_equal 200, test_status
      assert_equal "GET", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
      end

    it "should report a GET path with parameter" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      get "/employee_data/12"

      assert_equal "GrapeSimple./employee_data/:id", test_action
      assert_equal "http://example.org/employee_data/12", test_url
      assert_equal 200, test_status
      assert_equal "GET", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end

    it "should report a POST path" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      data = {
          :name => 'Tom',
          :address => 'Street',
          :age => 66
      }

      post '/employee_data', data

      assert_equal "GrapeSimple./employee_data", test_action
      assert_equal "http://example.org/employee_data", test_url
      assert_equal 201, test_status
      assert_equal "POST", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end

    it "should report a PUT path" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      put "/employee_data/12", { :address => 'Other Street' }

      assert_equal "GrapeSimple./employee_data/:id", test_action
      assert_equal "http://example.org/employee_data/12", test_url
      assert_equal 200, test_status
      assert_equal "PUT", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end

    it "should report a DELETE path" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      delete "/employee_data/12"

      assert_equal "GrapeSimple./employee_data/:id", test_action
      assert_equal "http://example.org/employee_data/12", test_url
      assert_equal 200, test_status
      assert_equal "DELETE", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end

    it "should report a nested GET path with parameters" do
      @app = GrapeSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      get "/employee_data/12/nested/34"

      assert_equal "GrapeSimple./employee_data/:id/nested/:child", test_action
      assert_equal "http://example.org/employee_data/12/nested/34", test_url
      assert_equal 200, test_status
      assert_equal "GET", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end

  end
end
