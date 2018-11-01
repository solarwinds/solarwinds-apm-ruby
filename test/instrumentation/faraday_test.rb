# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "Faraday" do
  before do
    clear_all_traces
    @collect_backtraces = AppOpticsAPM::Config[:faraday][:collect_backtraces]
    @log_args = AppOpticsAPM::Config[:faraday][:log_args]
  end

  after do
    AppOpticsAPM::Config[:faraday][:collect_backtraces] = @collect_backtraces
    AppOpticsAPM::Config[:faraday][:log_args] = @log_args
  end

  it 'Faraday should be defined and ready' do
    defined?(::Faraday).wont_match nil
  end

  it 'Faraday should have appoptics_apm methods defined' do
    [ :run_request_with_appoptics ].each do |m|
      ::Faraday::Connection.method_defined?(m).must_equal true
    end
  end

  it "should trace cross-app request" do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/games?q=1'
      response.headers["x-trace"].wont_match nil
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['Spec'].must_equal 'rsc'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteURL'].must_equal 'http://127.0.0.1:8101/games?q=1'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
  end

  it "should trace UNINSTRUMENTED cross-app request" do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8110') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/games?q=1'
      response.headers["x-trace"].wont_match nil
    end

    traces = get_all_traces
    traces.count.must_equal 6

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['Label'].must_equal 'exit'
    traces[3]['Spec'].must_equal 'rsc'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteURL'].must_equal 'http://127.0.0.1:8110/games?q=1'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'faraday'
    traces[4]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday request' do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['Spec'].must_equal 'rsc'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?q=ruby_test_suite'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday class style request' do
    AppOpticsAPM::API.start_trace('faraday_test') do
      Faraday.get('http://127.0.0.1:8101/', {:a => 1})
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[6]['Layer'].must_equal 'net-http'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['Spec'].must_equal 'rsc'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?a=1'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal '200'

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday with the excon adapter' do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :excon
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'excon'
    traces[2]['Label'].must_equal 'entry'
    traces[2]['Spec'].must_equal 'rsc'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'

    traces[2]['RemoteProtocol'].must_be_nil
    traces[2]['RemoteHost'].must_be_nil
    traces[2]['ServiceArg'].must_be_nil
    traces[6]['Layer'].must_equal 'excon'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['HTTPStatus'].must_equal 200

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
    traces[7]['Middleware'].must_equal '[Faraday::Adapter::Excon]'
  end

  it 'should trace a Faraday with the httpclient adapter' do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :httpclient
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'httpclient'
    traces[2]['Label'].must_equal 'entry'
    traces[2]['Spec'].must_equal 'rsc'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'

    traces[6]['Layer'].must_equal 'httpclient'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['HTTPStatus'].must_equal 200

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
    traces[7]['Middleware'].must_equal '[Faraday::Adapter::HTTPClient]'
  end

  it 'should trace a Faraday with the typhoeus adapter' do
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :typhoeus
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 9

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Label'].must_equal 'entry'

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
    traces[6]['Spec'].must_equal 'rsc'
    traces[6]['IsService'].must_equal 1
    traces[6]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?q=1'
    traces[6]['HTTPMethod'].must_equal 'GET'
    traces[6]['HTTPStatus'].must_equal 200

    traces[7]['Layer'].must_equal 'faraday'
    traces[7]['Label'].must_equal 'exit'
    traces[7]['Middleware'].must_equal '[Faraday::Adapter::Typhoeus]'
  end

  it 'should trace a Faraday with the UNINSTRUMENTED patron adapter' do
    AppOpticsAPM::Config[:faraday][:log_args] = true
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter :patron
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 7

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'rack'
    traces[2]['Label'].must_equal 'entry'

    traces[4]['Layer'].must_equal 'rack'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Status'].must_equal 200

    traces[5]['Spec'].must_equal 'rsc'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?q=1'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal 200
    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['Middleware'].must_equal '[Faraday::Adapter::Patron]'
  end

  it 'should trace a Faraday with the UNINSTRUMENTED patron adapter to UNINSTRUMENTED rack' do
    AppOpticsAPM::Config[:faraday][:log_args] = true
    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8110') do |faraday|
        faraday.adapter :patron
      end
      conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 4

    assert valid_edges?(traces), "Invalid edge in traces"
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:faraday][:collect_backtraces]

    traces[2]['Spec'].must_equal 'rsc'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteURL'].must_equal 'http://127.0.0.1:8110/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'
    traces[2]['HTTPStatus'].must_equal 200
    traces[2]['Layer'].must_equal 'faraday'
    traces[2]['Label'].must_equal 'exit'
    traces[2]['Middleware'].must_equal '[Faraday::Adapter::Patron]'
  end

  it 'should obey :collect_backtraces setting when true' do
    AppOpticsAPM::Config[:faraday][:collect_backtraces] = true

    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_has_key(traces, 'faraday', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    AppOpticsAPM::Config[:faraday][:collect_backtraces] = false

    AppOpticsAPM::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://127.0.0.1:8101') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'faraday', 'Backtrace')
  end
end
