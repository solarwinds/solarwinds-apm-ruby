# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"
require "mocha/mini_test"
require File.expand_path(File.dirname(__FILE__) + '/apps/sinatra_simple')

describe Sinatra do
  before do
    clear_all_traces
  end

  it "should trace a request to a simple sinatra stack" do
    @app = SinatraSimple

    r = get "/render"

    traces = get_all_traces

    traces.count.must_equal 9
    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rack')

    traces[2]['Layer'].must_equal "sinatra"
    traces[4]['Label'].must_equal "profile_entry"
    traces[7]['Controller'].must_equal "SinatraSimple"
    traces[8]['Label'].must_equal "exit"

    # Validate the existence of the response header
    r.headers.key?('X-Trace').must_equal true
    r.headers['X-Trace'].must_equal traces[8]['X-Trace']
  end

  it "should not have RUM code in the response" do
    @app = SinatraSimple

    r = get "/render"

    (r.body =~ /tly.js/).must_be_nil
  end

  it "should report the route with :id" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    TraceView::Span.expects(:createHttpSpan).with do |action, url, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947"

    r.body.must_match /123304952309747203947/

    assert_equal "/render/:id", test_action
    assert_equal "http://example.org", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end

  it "should report the route with :id and more" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    TraceView::Span.expects(:createHttpSpan).with do |action, url, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947/what"

    r.body.must_match /WOOT.*123304952309747203947/


    assert_equal "/render/:id/what", test_action
    assert_equal "http://example.org", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end

  it "should report the route with splats" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    TraceView::Span.expects(:createHttpSpan).with do |action, url, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/say/hello/to/world"

    r.body.must_match /hello world/

    assert_equal "/say/_/to/_", test_action
    assert_equal "http://example.org", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end

  it "should report the route with regex" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    TraceView::Span.expects(:createHttpSpan).with do |action, url, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/hello/friend"

    r.body.must_match /Hello, friend/

    assert_equal "_/hello_/___w___", test_action
    assert_equal "http://example.org", test_url
    assert_equal 200, test_status
    assert_equal "GET", test_method
    assert_equal 0, test_error
  end
end
