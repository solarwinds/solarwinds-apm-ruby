# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.


require "minitest_helper"
require "mocha/minitest"
require File.expand_path(File.dirname(__FILE__) + '/apps/sinatra_simple')

describe Sinatra do
  before do
    clear_all_traces
  end

  it "should trace a request to a simple sinatra stack" do
    @app = SinatraSimple

    r = get "/render"

    traces = get_all_traces

    traces.count.must_equal 8
    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rack')

    traces[1]['Layer'].must_equal "sinatra"
    traces[3]['Label'].must_equal "profile_entry"
    traces[6]['Controller'].must_equal "SinatraSimple"
    traces[7]['Label'].must_equal "exit"

    # Validate the existence of the response header
    r.headers.key?('X-Trace').must_equal true
    r.headers['X-Trace'].must_equal traces[7]['X-Trace']
  end

  it "should log an error on exception" do
    @app = SinatraSimple

    SinatraSimple.any_instance.expects(:dispatch_without_appoptics).raises(StandardError.new('Hello Sinatra'))

    begin
      r = get "/render"
    rescue
    end

    traces = get_all_traces

    traces.count.must_equal 5
    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rack')

    traces[1]['Layer'].must_equal "sinatra"

    error_trace = traces.find{ |trace| trace['Label'] == 'error' }

    error_trace['Layer'].must_equal 'sinatra'
    error_trace['Spec'].must_equal 'error'
    error_trace['ErrorClass'].must_equal 'StandardError'
    error_trace['ErrorMsg'].must_equal 'Hello Sinatra'
    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 1
  end

  it "should not have RUM code in the response" do
    @app = SinatraSimple

    r = get "/render"

    (r.body =~ /tly.js/).must_be_nil
  end

  it "should report the route with :id" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947"

    r.body.must_match /123304952309747203947/

    assert_equal "SinatraSimple.GET /render/:id", test_action
    assert_equal "http://example.org/render/123304952309747203947", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  it "should report the route with :id and more" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947/what"

    r.body.must_match /WOOT.*123304952309747203947/

    assert_equal "SinatraSimple.GET /render/:id/what", test_action
    assert_equal "http://example.org/render/123304952309747203947/what", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  it "should report the route with splats" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/say/hello/to/world"

    r.body.must_match /hello world/

    assert_equal "SinatraSimple.GET /say/*/to/*", test_action
    assert_equal "http://example.org/say/hello/to/world", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error

    assert_controller_action(test_action)
  end

  if RUBY_VERSION > '2.2'
    it "should report the route with regex" do
      @app = SinatraSimple
      test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
      AppOpticsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      r = get "/hello/friend"

      r.body.must_match /Hello, friend/

      test_action.must_match  "SinatraSimple.GET \\/hello\\/([\\w]+)", test_action
      assert_equal "http://example.org/hello/friend", test_url
      assert_equal 200, test_status
      assert_equal "GET", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end
  end
end
