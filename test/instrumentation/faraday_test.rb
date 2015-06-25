# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

describe "Faraday" do
  before do
    clear_all_traces
    @collect_backtraces = TraceView::Config[:faraday][:collect_backtraces]
  end

  after do
    TraceView::Config[:faraday][:collect_backtraces] = @collect_backtraces
  end

  it 'Faraday should be defined and ready' do
    defined?(::Faraday).wont_match nil
  end

  it 'Faraday should have traceview methods defined' do
    [ :run_request_with_traceview ].each do |m|
      ::Faraday::Connection.method_defined?(m).must_equal true
    end
  end

  it "should trace cross-app request" do
    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/games?q=1'
      response.headers["x-trace"].wont_match nil
    end

    traces = get_all_traces
    traces.count.must_equal 11

    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal TraceView::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteProtocol'].must_equal 'HTTP'
    traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
    traces[6]['ServiceArg'].must_equal '/games?q=1'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'net-http'
    traces[7]['Label'].must_equal 'exit'

    traces[8]['Layer'].must_equal 'faraday'
    traces[9]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday request' do
    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 11

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal TraceView::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['Label'].must_equal 'info'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteProtocol'].must_equal 'HTTP'
    traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
    traces[6]['ServiceArg'].must_equal '/?q=ruby_test_suite'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'net-http'
    traces[7]['Label'].must_equal 'exit'

    traces[8]['Layer'].must_equal 'faraday'
    traces[8]['Label'].must_equal 'info'

    traces[9]['Layer'].must_equal 'faraday'
    traces[9]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday class style request' do
    TraceView::API.start_trace('faraday_test') do
      Faraday.get('http://127.0.0.1:8101/', {:a => 1})
    end

    traces = get_all_traces
    traces.count.must_equal 11

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal TraceView::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['Label'].must_equal 'info'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteProtocol'].must_equal 'HTTP'
    traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
    traces[6]['ServiceArg'].must_equal '/?a=1'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'net-http'
    traces[7]['Label'].must_equal 'exit'

    traces[8]['Layer'].must_equal 'faraday'
    traces[8]['Label'].must_equal 'info'

    traces[9]['Layer'].must_equal 'faraday'
    traces[9]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday with the excon adapter' do
    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :excon
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 10

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal TraceView::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'excon'
    traces[2]['Label'].must_equal 'entry'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteProtocol'].must_equal 'HTTP'
    traces[2]['RemoteHost'].must_equal '127.0.0.1'
    traces[2]['ServiceArg'].must_equal '/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'

    traces[6]['Layer'].must_equal 'excon'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['HTTPStatus'].must_equal 200

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'info'
    unless RUBY_VERSION < '1.9.3'
      # FIXME: Ruby 1.8 is reporting an object instance instead of
      # an array
      traces[7]['Middleware'].must_equal '[Faraday::Adapter::Excon]'
    end

    traces[8]['Layer'].must_equal 'faraday'
    traces[8]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday with the httpclient adapter' do
    skip "FIXME: once HTTPClient instrumentation is done"

    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :httpclient
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 10

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal TraceView::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'excon'
    traces[2]['Label'].must_equal 'entry'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteProtocol'].must_equal 'HTTP'
    traces[2]['RemoteHost'].must_equal '127.0.0.1'
    traces[2]['ServiceArg'].must_equal '/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'

    traces[6]['Layer'].must_equal 'excon'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['HTTPStatus'].must_equal 200

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'info'
    unless RUBY_VERSION < '1.9.3'
      # FIXME: Ruby 1.8 is reporting an object instance instead of
      # an array
      traces[7]['Middleware'].must_equal '[Faraday::Adapter::Excon]'
    end

    traces[8]['Layer'].must_equal 'faraday'
    traces[8]['Label'].must_equal 'exit'
  end

  it 'should obey :collect_backtraces setting when true' do
    TraceView::Config[:faraday][:collect_backtraces] = true

    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_has_key(traces, 'faraday', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    TraceView::Config[:faraday][:collect_backtraces] = false

    TraceView::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'faraday', 'Backtrace')
  end
end
