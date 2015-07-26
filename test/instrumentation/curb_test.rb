# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'
require 'traceview/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

class CurbTest < Minitest::Test
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  def test_reports_version_init
    init_kvs = ::TraceView::Util.build_init_report
    assert init_kvs.key?('Ruby.Curb.Version')
    assert_equal init_kvs['Ruby.Curb.Version'], "Curb-#{::Curl::VERSION}"
  end

  def test_class_get_request
    clear_all_traces

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl.get('http://127.0.0.1:8101/')
    end

    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal 'GET',                     traces[1]['HTTPMethod'], "HTTP Method"
    assert_equal "http://127.0.0.1:8101/",  traces[1]['RemoteURL']
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_class_delete_request
    clear_all_traces

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl.delete('http://127.0.0.1:8101/?curb_delete_test', :id => 1)
    end

    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal 'DELETE',                  traces[1]['HTTPMethod'], "HTTP Method"
    assert_equal "http://127.0.0.1:8101/?curb_delete_test",  traces[1]['RemoteURL']
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_class_post_request
    clear_all_traces

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl.post('http://127.0.0.1:8101/')
    end

    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal "http://127.0.0.1:8101/",  traces[1]['RemoteURL']
    assert_equal 'POST',                    traces[1]['HTTPMethod'], "HTTP Method"
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_easy_class_perform
    clear_all_traces

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl::Easy.perform("http://127.0.0.1:8101/")
    end

    assert response.is_a?(::Curl::Easy)
    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7,                         traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal "http://127.0.0.1:8101/",  traces[1]['RemoteURL']
    assert_equal 'GET',                     traces[1]['HTTPMethod'], "HTTP Method"
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_easy_http_head
    clear_all_traces

    c = nil

    TraceView::API.start_trace('curb_tests') do
      c = Curl::Easy.new("http://127.0.0.1:8101/")
      c.http_head
    end

    assert c.is_a?(::Curl::Easy), "Response type"
    assert c.response_code == 200
    assert c.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal "http://127.0.0.1:8101/",  traces[1]['RemoteURL']
    assert_equal 'GET',                     traces[1]['HTTPMethod'], "HTTP Method"
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_class_fetch_with_block
    clear_all_traces

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl::Easy.perform("http://127.0.0.1:8101/") do |curl|
        curl.headers["User-Agent"] = "TraceView 2000"
      end
    end

    assert response.is_a?(::Curl::Easy), "Response type"
    assert response.response_code == 200
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal traces[5]['Label'], 'exit'
    assert_equal 1,                         traces[1]['IsService']
    assert_equal "http://127.0.0.1:8101/",  traces[1]['RemoteURL']
    assert_equal 'GET',                     traces[1]['HTTPMethod']
    assert traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']
  end

  def test_cross_app_tracing
    clear_all_traces

    @cross_host = TraceView::Config[:curb][:cross_host]
    TraceView::Config[:curb][:cross_host] = true

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = ::Curl.get('http://127.0.0.1:8101/?curb_cross_host=1')
    end

    xtrace = response.headers['X-Trace']
    assert xtrace, "X-Trace response header"
    assert TraceView::XTrace.valid?(xtrace)
    assert response.header_str =~ /X-Trace/, "X-Trace response header"

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")
    assert valid_edges?(traces), "Trace edge validation"

    assert_equal 'curb',                    traces[1]['Layer']
    assert_equal 'entry',                   traces[1]['Label']
    assert_equal 1,                         traces[1]['IsService']
    assert_equal 'GET',                     traces[1]['HTTPMethod'], "HTTP Method"
    assert_equal "http://127.0.0.1:8101/?curb_cross_host=1&",  traces[1]['RemoteURL']
    assert       traces[1].key?('Backtrace')

    assert_equal 'curb',                    traces[5]['Layer']
    assert_equal 'exit',                    traces[5]['Label']
    assert_equal 200,                       traces[5]['HTTPStatus']

    TraceView::Config[:curb][:cross_host] = @cross_host
  end

  def test_multi_basic
    clear_all_traces

    responses = nil
    easy_options = {:follow_location => true}
    multi_options = {:pipeline => false}

    urls = []
    urls << "http://127.0.0.1:8101/?one=1"
    urls << "http://127.0.0.1:8101/?two=2"
    urls << "http://127.0.0.1:8101/?three=3"

    TraceView::API.start_trace('curb_tests') do
      responses = Curl::Multi.get(urls, easy_options, multi_options) do |easy|
        nil
      end
    end

    traces = get_all_traces
    assert_equal 13, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[11]['Layer'], 'curb_multi'
    assert_equal traces[11]['Label'], 'exit'
  end

  def test_multi_basic_pipeline
    clear_all_traces

    responses = nil
    easy_options = {:follow_location => true}
    multi_options = {:pipeline => true}

    urls = []
    urls << "http://127.0.0.1:8101/?one=1"
    urls << "http://127.0.0.1:8101/?two=2"
    urls << "http://127.0.0.1:8101/?three=3"

    TraceView::API.start_trace('curb_tests') do
      responses = Curl::Multi.get(urls, easy_options, multi_options) do |easy|
        nil
      end
    end

    traces = get_all_traces
    assert_equal 13, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")

    assert_equal traces[1]['Layer'], 'curb_multi'
    assert_equal traces[1]['Label'], 'entry'
    assert_equal traces[11]['Layer'], 'curb_multi'
    assert_equal traces[11]['Label'], 'exit'
  end

  def test_requests_with_errors
    clear_all_traces

    begin
      TraceView::API.start_trace('curb_tests') do
        Curl.get('http://asfjalkfjlajfljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal 5, traces.count, "Trace count"
    validate_outer_layers(traces, "curb_tests")
    assert valid_edges?(traces), "Trace edge validation"

    assert_equal 1,                                traces[1]['IsService']
    assert_equal 'http://asfjalkfjlajfljkaljf/',   traces[1]['RemoteURL']
    assert_equal 'GET',                            traces[1]['HTTPMethod']
    assert traces[1].key?('Backtrace')

    assert_equal 'curb',                           traces[2]['Layer']
    assert_equal 'error',                          traces[2]['Label']
    assert_equal "Curl::Err::HostResolutionError", traces[2]['ErrorClass']
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')

    assert_equal 'curb',                           traces[3]['Layer']
    assert_equal 'exit',                           traces[3]['Label']
  end

  def test_obey_log_args_when_false
    @log_args = TraceView::Config[:curb][:log_args]
    clear_all_traces

    TraceView::Config[:curb][:log_args] = false

    http = nil

    TraceView::API.start_trace('curb_tests') do
      http = Curl.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    assert_equal "http://127.0.0.1:8101/",         traces[1]['RemoteURL']

    TraceView::Config[:curb][:log_args] = @log_args
  end

  def test_obey_log_args_when_true
    @log_args = TraceView::Config[:curb][:log_args]
    clear_all_traces

    TraceView::Config[:curb][:log_args] = true

    http = nil

    TraceView::API.start_trace('curb_tests') do
      http = ::Curl.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    assert_equal 7, traces.count, "Trace count"
    assert_equal "http://127.0.0.1:8101/?blah=1&", traces[1]['RemoteURL']

    TraceView::Config[:curb][:log_args] = @log_args
  end

  def test_without_tracing_class_get
    clear_all_traces

    @tm = TraceView::Config[:tracing_mode]
    TraceView::Config[:tracing_mode] = :never

    response = nil

    TraceView::API.start_trace('httpclient_tests') do
      response = ::Curl.get('http://127.0.0.1:8101/?blah=1')
    end

    assert response.headers['X-Trace'] == nil
    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200

    traces = get_all_traces
    assert_equal 0, traces.count, "Trace count"

    TraceView::Config[:tracing_mode] = @tm
  end

  def test_without_tracing_easy_perform
    clear_all_traces

    @tm = TraceView::Config[:tracing_mode]
    TraceView::Config[:tracing_mode] = :never

    response = nil

    TraceView::API.start_trace('curb_tests') do
      response = Curl::Easy.perform("http://127.0.0.1:8101/")
    end

    assert response.headers['X-Trace'] == nil
    assert response.body_str == "Hello TraceView!"
    assert response.response_code == 200

    traces = get_all_traces
    assert_equal 0, traces.count, "Trace count"

    TraceView::Config[:tracing_mode] = @tm
  end

  def test_obey_collect_backtraces_when_true
    @cb = TraceView::Config[:curb][:collect_backtraces]
    TraceView::Config[:curb][:collect_backtraces] = true

    TraceView::API.start_trace('curb_test') do
      Curl.get("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    layer_has_key(traces, 'curb', 'Backtrace')

    TraceView::Config[:curb][:collect_backtraces] = @cb
  end

  def test_obey_collect_backtraces_when_false
    @cb = TraceView::Config[:curb][:collect_backtraces]
    TraceView::Config[:curb][:collect_backtraces] = false

    TraceView::API.start_trace('curb_test') do
      Curl.get("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'curb', 'Backtrace')

    TraceView::Config[:curb][:collect_backtraces] = @cb
  end
end

