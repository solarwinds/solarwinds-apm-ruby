# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"
require "mocha/minitest"
require File.expand_path(File.dirname(__FILE__) + '/apps/sinatra_simple')

describe Sinatra do
  before do
    clear_all_traces
    @bt = SolarWindsAPM::Config[:sinatra][:collect_backtraces]
  end

  after do
    SolarWindsAPM::Config[:sinatra][:collect_backtraces] = @bt
  end

  it "should trace a request to a simple sinatra stack" do
    @app = SinatraSimple

    r = get "/render"

    traces = get_all_traces

    _(traces.count).must_equal 6
    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'rack')

    _(traces[1]['Layer']).must_equal "sinatra"
    _(traces[2]['Label']).must_equal "entry"
    _(traces[4]['Controller']).must_equal "SinatraSimple"
    _(traces[5]['Label']).must_equal "exit"

    layer_has_key_once(traces, 'sinatra', 'Backtrace')

    # Validate the existence of the response header
    _(r.headers.key?('X-Trace')).must_equal true
    _(r.headers['X-Trace']).must_equal traces[5]['sw.trace_context']
  end

  it "should log an error on exception" do
    SolarWindsAPM::Config[:sinatra][:collect_backtraces] = false
    @app = SinatraSimple

    SinatraSimple.any_instance.expects(:dispatch_without_appoptics).raises(StandardError.new('Hello Sinatra'))

    begin
      _ = get "/render"
    rescue
    end

    traces = get_all_traces

    _(traces.count).must_equal 5
    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'rack')

    _(traces[1]['Layer']).must_equal "sinatra"

    error_traces = traces.select { |trace| trace['Label'] == 'error' }
    _(error_traces.size).must_equal 1

    error_trace = error_traces[0]
    _(error_trace['Layer']).must_equal 'sinatra'
    _(error_trace['Spec']).must_equal 'error'
    _(error_trace['ErrorClass']).must_equal 'StandardError'
    _(error_trace['ErrorMsg']).must_equal 'Hello Sinatra'
  end

  it 'should not report backtraces' do
    SolarWindsAPM::Config[:sinatra][:collect_backtraces] = false
    @app = SinatraSimple

    r = get "/render"

    traces = get_all_traces

    layer_doesnt_have_key(traces, 'sinatra', 'Backtrace')
  end

  it "should not have RUM code in the response" do
    @app = SinatraSimple

    r = get "/render"

    _((r.body =~ /tly.js/)).must_be_nil
  end

  it "should report the route with :id" do
    @app = SinatraSimple
    test_action, test_url, test_status, test_method, test_error = nil, nil, nil, nil, nil
    SolarWindsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947"

    _(r.body).must_match /123304952309747203947/

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
    SolarWindsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/render/123304952309747203947/what"

    _(r.body).must_match /WOOT.*123304952309747203947/

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
    SolarWindsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
      test_action = action
      test_url = url
      test_status = status
      test_method = method
      test_error = error
    end.once

    r = get "/say/hello/to/world"

    _(r.body).must_match /hello world/

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
      SolarWindsAPM::Span.expects(:createHttpSpan).with do |action, url, _, _duration, status, method, error|
        test_action = action
        test_url = url
        test_status = status
        test_method = method
        test_error = error
      end.once

      r = get "/hello/friend"

      _(r.body).must_match /Hello, friend/

      _(test_action).must_match "SinatraSimple.GET \\/hello\\/([\\w]+)", test_action
      assert_equal "http://example.org/hello/friend", test_url
      assert_equal 200, test_status
      assert_equal "GET", test_method
      assert_equal 0, test_error

      assert_controller_action(test_action)
    end
  end
end
