# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'net/http'

describe "Net::HTTP"  do
  before do
    clear_all_traces
    @collect_backtraces = AppOpticsAPM::Config[:nethttp][:collect_backtraces]
    @log_args = AppOpticsAPM::Config[:nethttp][:log_args]
  end

  after do
    AppOpticsAPM::Config[:nethttp][:collect_backtraces] = @collect_backtraces
    AppOpticsAPM::Config[:nethttp][:log_args] = @log_args
  end

  it 'Net::HTTP should be defined and ready' do
    _(defined?(::Net::HTTP)).wont_match nil
  end

  it 'Net::HTTP should have AppOpticsAPM instrumentation' do
    _(::Net::HTTP.ancestors.include?(AppopticsAPM::Inst::NetHttp)).must_equal true
  end

  it "should trace a Net::HTTP request to an instr'd app" do
    AppOpticsAPM::API.start_trace('net-http_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/?q=1')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      # The HTTP response should have an X-Trace header inside of it
      _(response["x-trace"]).wont_match nil
    end

    traces = get_all_traces
    _(traces.count).must_equal 6
    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'net-http_test')

    _(traces[1]['Layer']).must_equal 'net-http'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'rack'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[3]['Layer']).must_equal 'rack'
    _(traces[3]['Label']).must_equal 'exit'

    _(traces[4]['Spec']).must_equal 'rsc'
    _(traces[4]['IsService']).must_equal 1
    _(traces[4]['RemoteURL']).must_equal 'http://127.0.0.1:8101/?q=1'
    _(traces[4]['HTTPMethod']).must_equal "GET"
    _(traces[4]['HTTPStatus']).must_equal "200"
    _(traces[4].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:nethttp][:collect_backtraces]
  end

  it "should trace a GET request" do
    AppOpticsAPM::API.start_trace('net-http_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    traces = get_all_traces
    _(traces.count).must_equal 6
    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'net-http_test')

    _(traces[1]['Layer']).must_equal 'net-http'
    _(traces[4]['Spec']).must_equal 'rsc'
    _(traces[4]['IsService']).must_equal 1
    _(traces[4]['RemoteURL']).must_equal 'http://127.0.0.1:8101/?q=1'
    _(traces[4]['HTTPMethod']).must_equal "GET"
    _(traces[4]['HTTPStatus']).must_equal "200"
    _(traces[4].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:nethttp][:collect_backtraces]
  end

  it "should trace a GET request to an uninstrumented app" do
    AppOpticsAPM::API.start_trace('net-http_test', '', {}) do
      uri = URI('http://127.0.0.1:8110/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    traces = get_all_traces
    _(traces.count).must_equal 4
    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'net-http_test')

    _(traces[1]['Layer']).must_equal 'net-http'
    _(traces[2]['Spec']).must_equal 'rsc'
    _(traces[2]['IsService']).must_equal 1
    _(traces[2]['RemoteURL']).must_equal 'http://127.0.0.1:8110/?q=1'
    _(traces[2]['HTTPMethod']).must_equal "GET"
    _(traces[2]['HTTPStatus']).must_equal "200"
    _(traces[2].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:nethttp][:collect_backtraces]
  end

  it "should obey :log_args setting when true" do
    AppOpticsAPM::Config[:nethttp][:log_args] = true

    AppOpticsAPM::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    _(traces[4]['RemoteURL']).must_equal 'http://127.0.0.1:8101/?q=ruby_test_suite'
  end

  it "should obey :log_args setting when false" do
    AppOpticsAPM::Config[:nethttp][:log_args] = false

    AppOpticsAPM::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    _(traces[4]['RemoteURL']).must_equal 'http://127.0.0.1:8101/'
  end

  it "should obey :collect_backtraces setting when true" do
    AppOpticsAPM::Config[:nethttp][:collect_backtraces] = true

    AppOpticsAPM::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    layer_has_key(traces, 'net-http', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    AppOpticsAPM::Config[:nethttp][:collect_backtraces] = false

    AppOpticsAPM::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'net-http', 'Backtrace')
  end
end
