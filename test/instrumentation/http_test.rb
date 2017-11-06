# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'net/http'

describe "Net::HTTP"  do
  before do
    clear_all_traces
    @collect_backtraces = AppOptics::Config[:nethttp][:collect_backtraces]
    @log_args = AppOptics::Config[:nethttp][:log_args]
  end

  after do
    AppOptics::Config[:nethttp][:collect_backtraces] = @collect_backtraces
    AppOptics::Config[:nethttp][:log_args] = @log_args
  end

  it 'Net::HTTP should be defined and ready' do
    defined?(::Net::HTTP).wont_match nil
  end

  it 'Net::HTTP should have appoptics methods defined' do
    [ :request_with_appoptics ].each do |m|
      ::Net::HTTP.method_defined?(m).must_equal true
    end
  end

  it "should trace a Net::HTTP request to an instr'd app" do
    AppOptics::API.start_trace('net-http_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/?q=1')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      # The HTTP response should have an X-Trace header inside of it
      response["x-trace"].wont_match nil
    end

    traces = get_all_traces
    traces.count.must_equal 8
    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'net-http_test')

    traces[1]['Layer'].must_equal 'net-http'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'rack'
    traces[2]['Label'].must_equal 'entry'

    traces[3]['Layer'].must_equal 'rack'
    traces[3]['Label'].must_equal 'info'

    traces[4]['Layer'].must_equal 'rack'
    traces[4]['Label'].must_equal 'exit'

    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteProtocol'].must_equal "HTTP"
    traces[5]['RemoteHost'].must_equal "127.0.0.1:8101"
    traces[5]['ServiceArg'].must_equal "/?q=1"
    traces[5]['HTTPMethod'].must_equal "GET"
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].has_key?('Backtrace').must_equal AppOptics::Config[:nethttp][:collect_backtraces]
  end

  it "should trace a GET request" do
    AppOptics::API.start_trace('net-http_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    traces = get_all_traces
    traces.count.must_equal 8
    valid_edges?(traces).must_equal true

    validate_outer_layers(traces, 'net-http_test')

    traces[1]['Layer'].must_equal 'net-http'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteProtocol'].must_equal "HTTP"
    traces[5]['RemoteHost'].must_equal "127.0.0.1:8101"
    traces[5]['ServiceArg'].must_equal "/?q=1"
    traces[5]['HTTPMethod'].must_equal "GET"
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].has_key?('Backtrace').must_equal AppOptics::Config[:nethttp][:collect_backtraces]
  end

  it "should obey :log_args setting when true" do
    AppOptics::Config[:nethttp][:log_args] = true

    AppOptics::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    traces[5]['ServiceArg'].must_equal '/?q=ruby_test_suite'
  end

  it "should obey :log_args setting when false" do
    AppOptics::Config[:nethttp][:log_args] = false

    AppOptics::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    traces[5]['ServiceArg'].must_equal '/'
  end

  it "should obey :collect_backtraces setting when true" do
    AppOptics::Config[:nethttp][:collect_backtraces] = true

    AppOptics::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    layer_has_key(traces, 'net-http', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    AppOptics::Config[:nethttp][:collect_backtraces] = false

    AppOptics::API.start_trace('nethttp_test', '', {}) do
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = false
      http.get('/?q=ruby_test_suite').read_body
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'net-http', 'Backtrace')
  end
end
