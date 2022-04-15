# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "RestClient" do
  before do
    clear_all_traces
    @collect_backtraces = SolarWindsAPM::Config[:rest_client][:collect_backtraces]
    @tm = SolarWindsAPM::Config[:tracing_mode]

    SolarWindsAPM::Config[:tracing_mode] = :enabled

    # TODO remove with NH-11132
    # not a request entry point, context set up in test with start_trace
    SolarWindsAPM::Context.clear
  end

  after do
    SolarWindsAPM::Config[:rest_client][:collect_backtraces] = @collect_backtraces
    SolarWindsAPM::Config[:tracing_mode] = @tm
  end

  it 'RestClient should be defined and ready' do
    _(defined?(::RestClient)).wont_match nil
  end

  it 'RestClient should have SolarWinds instrumentation prepended' do
    assert RestClient::Request.ancestors.include?(SolarWindsAPM::Inst::RestClientRequest)
  end

  it "should report rest-client version in __Init" do
    init_kvs = ::SolarWindsAPM::Util.build_init_report

    _(init_kvs.key?('Ruby.rest-client.Version')).must_equal true
    _(init_kvs['Ruby.rest-client.Version']).must_equal ::RestClient::VERSION
  end

  it "should trace a request to an instr'd app" do
    response = nil

    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      response = RestClient.get 'http://127.0.0.1:8101/'
    end

    traces = get_all_traces
    _(traces.count).must_equal 8

    _(valid_edges?(traces, false)).must_equal true, "flaky test"
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'net-http'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[5]['Layer']).must_equal 'net-http'
    _(traces[5]['Label']).must_equal 'exit'
    _(traces[5]['IsService']).must_equal 1
    _(traces[5]['RemoteURL']).must_equal 'http://127.0.0.1:8101/'
    _(traces[5]['HTTPMethod']).must_equal 'GET'
    _(traces[5]['HTTPStatus']).must_equal "200"
    _(traces[5].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[6]['Layer']).must_equal 'rest-client'
    _(traces[6]['Label']).must_equal 'exit'

    _(response.headers.key?(:x_trace)).wont_equal nil
    tracestring = response.headers[:x_trace]

    _(SolarWindsAPM::TraceString.valid?(tracestring)).must_equal true
  end

  it 'should trace a raw GET request' do
    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      RestClient.get 'http://127.0.0.1:8101/?a=1'
    end

    traces = get_all_traces
    _(traces.count).must_equal 8

    _(valid_edges?(traces, false)).must_equal true, "flaky test"
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'net-http'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[5]['Layer']).must_equal 'net-http'
    _(traces[5]['Label']).must_equal 'exit'
    _(traces[5]['IsService']).must_equal 1
    _(traces[5]['RemoteURL']).must_equal 'http://127.0.0.1:8101/?a=1'
    _(traces[5]['HTTPMethod']).must_equal 'GET'
    _(traces[5]['HTTPStatus']).must_equal "200"
    _(traces[5].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[6]['Layer']).must_equal 'rest-client'
    _(traces[6]['Label']).must_equal 'exit'
  end

  it 'should trace a raw POST request' do
    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      RestClient.post 'http://127.0.0.1:8101/', :param1 => 'one', :nested => { :param2 => 'two' }
    end

    traces = get_all_traces
    _(traces.count).must_equal 8

    _(valid_edges?(traces, false)).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'net-http'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[5]['Layer']).must_equal 'net-http'
    _(traces[5]['Label']).must_equal 'exit'
    _(traces[5]['IsService']).must_equal 1
    _(traces[5]['RemoteURL']).must_equal 'http://127.0.0.1:8101/'
    _(traces[5]['HTTPMethod']).must_equal 'POST'
    _(traces[5]['HTTPStatus']).must_equal "200"
    _(traces[5].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[6]['Layer']).must_equal 'rest-client'
    _(traces[6]['Label']).must_equal 'exit'
  end

  it 'should trace a ActiveResource style GET request' do
    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      resource = RestClient::Resource.new 'http://127.0.0.1:8101/?a=1'
      resource.get
    end

    traces = get_all_traces
    _(traces.count).must_equal 8

    _(valid_edges?(traces, false)).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'net-http'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[5]['Layer']).must_equal 'net-http'
    _(traces[5]['Label']).must_equal 'exit'
    _(traces[5]['IsService']).must_equal 1
    _(traces[5]['RemoteURL']).must_equal 'http://127.0.0.1:8101/?a=1'
    _(traces[5]['HTTPMethod']).must_equal 'GET'
    _(traces[5]['HTTPStatus']).must_equal "200"
    _(traces[5].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[6]['Layer']).must_equal 'rest-client'
    _(traces[6]['Label']).must_equal 'exit'
  end

  it 'should trace requests with redirects' do
    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      resource = RestClient::Resource.new 'http://127.0.0.1:8101/redirectme?redirect_test'
      response = resource.get
    end

    traces = get_all_traces
    _(traces.count).must_equal 14

    _(valid_edges?(traces, false)).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'net-http'
    _(traces[2]['Label']).must_equal 'entry'

    _(traces[5]['Layer']).must_equal 'net-http'
    _(traces[5]['Label']).must_equal 'exit'
    _(traces[5]['IsService']).must_equal 1
    _(traces[5]['RemoteURL']).must_equal 'http://127.0.0.1:8101/redirectme?redirect_test'
    _(traces[5]['HTTPMethod']).must_equal 'GET'
    _(traces[5]['HTTPStatus']).must_equal "301"
    _(traces[5].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[6]['Layer']).must_equal 'rest-client'
    _(traces[6]['Label']).must_equal 'entry'

    _(traces[7]['Layer']).must_equal 'net-http'
    _(traces[7]['Label']).must_equal 'entry'

    _(traces[10]['Layer']).must_equal 'net-http'
    _(traces[10]['Label']).must_equal 'exit'
    _(traces[10]['IsService']).must_equal 1
    _(traces[10]['RemoteURL']).must_equal 'http://127.0.0.1:8101/'
    _(traces[10]['HTTPMethod']).must_equal 'GET'
    _(traces[10]['HTTPStatus']).must_equal "200"
    _(traces[10].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces[11]['Layer']).must_equal 'rest-client'
    _(traces[11]['Label']).must_equal 'exit'

    _(traces[12]['Layer']).must_equal 'rest-client'
    _(traces[12]['Label']).must_equal 'exit'
  end

  it 'should trace and capture raised exceptions' do
    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      begin
        RestClient.get 'http://s6KTgaz7636z/resource'
      rescue
        # We want an exception to be raised.  Just don't raise
        # it beyond this point.
      end
    end

    traces = get_all_traces
    _(traces.count).must_equal 5

    _(valid_edges?(traces)).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    _(traces[1]['Layer']).must_equal 'rest-client'
    _(traces[1]['Label']).must_equal 'entry'

    _(traces[2]['Layer']).must_equal 'rest-client'
    _(traces[2]['Spec']).must_equal 'error'
    _(traces[2]['Label']).must_equal 'error'
    _(traces[2]['ErrorClass']).must_equal 'SocketError'
    _(traces[2].key?('ErrorMsg')).must_equal true
    _(traces[2].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:nethttp][:collect_backtraces]

    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1

    _(traces[3]['Layer']).must_equal 'rest-client'
    _(traces[3]['Label']).must_equal 'exit'
  end

  it 'should obey :collect_backtraces setting when true' do
    SolarWindsAPM::Config[:rest_client][:collect_backtraces] = true

    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      RestClient.get('http://127.0.0.1:8101/', { :a => 1 })
    end

    traces = get_all_traces
    layer_has_key(traces, 'rest-client', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    SolarWindsAPM::Config[:rest_client][:collect_backtraces] = false

    SolarWindsAPM::SDK.start_trace('rest_client_test') do
      RestClient.get('http://127.0.0.1:8101/', { :a => 1 })
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'rest-client', 'Backtrace')
  end
end
