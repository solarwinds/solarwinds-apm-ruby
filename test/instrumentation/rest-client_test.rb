require 'minitest_helper'

describe Oboe::Inst::RestClientRequest do
  before do
    clear_all_traces
    @collect_backtraces = Oboe::Config[:rest_client][:collect_backtraces]
  end

  after do
    Oboe::Config[:rest_client][:collect_backtraces] = @collect_backtraces
  end

  it 'RestClient should be defined and ready' do
    defined?(::RestClient).wont_match nil
  end

  it 'RestClient should have oboe methods defined' do
    [ :execute_with_oboe ].each do |m|
      ::RestClient::Request.method_defined?(m).must_equal true
    end
  end

  it "should trace a rest-client request to an instr'd app" do
    response = nil

    Oboe::API.start_trace('rest_client_test') do
      response = RestClient.get 'http://gameface.in/gamers'
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'rest-client'
    traces[2]['Label'].must_equal 'exit'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteProtocol'].must_equal 'HTTP'
    traces[2]['RemoteHost'].must_equal 'gameface.in'
    traces[2]['ServiceArg'].must_equal '/gamers'
    traces[2]['HTTPMethod'].must_equal 'GET'
    traces[2]['HTTPStatus'].must_equal 200
    traces[2].key?('Backtrace').must_equal Oboe::Config[:rest_client][:collect_backtraces]

    response.headers.key?(:x_trace).wont_equal nil
    xtrace = response.headers[:x_trace]
    Oboe::XTrace.valid?(xtrace).must_equal true
  end

  it 'should trace a rest-client GET request' do
    reponse = nil

    Oboe::API.start_trace('rest_client_test') do
      response = RestClient.get 'http://www.appneta.com/products/traceview?a=1'
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'rest-client'
    traces[2]['Label'].must_equal 'exit'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteProtocol'].must_equal 'HTTP'
    traces[2]['RemoteHost'].must_equal 'www.appneta.com'
    traces[2]['ServiceArg'].must_equal '/products/traceview?a=1'
    traces[2]['HTTPMethod'].must_equal 'GET'
    traces[2]['HTTPStatus'].must_equal 200
    traces[2].key?('Backtrace').must_equal Oboe::Config[:rest_client][:collect_backtraces]
  end

  it 'should obey :collect_backtraces setting when true' do
    Oboe::Config[:rest_client][:collect_backtraces] = true

    Oboe::API.start_trace('rest_client_test') do
      RestClient.get('http://www.appneta.com', {:a => 1})
    end

    traces = get_all_traces
    layer_has_key(traces, 'rest-client', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    Oboe::Config[:rest_client][:collect_backtraces] = false

    Oboe::API.start_trace('rest_client_test') do
      RestClient.get('http://www.appneta.com', {:a => 1})
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'rest-client', 'Backtrace')
  end
end
