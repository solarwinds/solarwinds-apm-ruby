require 'minitest_helper'

describe Oboe::Inst::FaradayConnection do
  before do
    clear_all_traces
    @collect_backtraces = Oboe::Config[:faraday][:collect_backtraces]
  end

  after do
    Oboe::Config[:faraday][:collect_backtraces] = @collect_backtraces
  end

  it 'Faraday should be defined and ready' do
    defined?(::Faraday).wont_match nil
  end

  it 'Faraday should have oboe methods defined' do
    [ :run_request_with_oboe ].each do |m|
      ::Faraday::Connection.method_defined?(m).must_equal true
    end
  end

  it "should trace a Faraday request to an instr'd app" do
    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.appneta.com') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 7

    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['IsService'].must_equal '1'
    traces[3]['RemoteProtocol'].must_equal 'HTTP'
    traces[3]['RemoteHost'].must_equal 'www.appneta.com'
    traces[3]['ServiceArg'].must_equal '/?q=ruby_test_suite'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'net-http'
    traces[4]['Label'].must_equal 'exit'

    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday request' do
    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.google.com') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 7

    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['IsService'].must_equal '1'
    traces[3]['RemoteProtocol'].must_equal 'HTTP'
    traces[3]['RemoteHost'].must_equal 'www.google.com'
    traces[3]['ServiceArg'].must_equal '/?q=ruby_test_suite'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'net-http'
    traces[4]['Label'].must_equal 'exit'

    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday with an alternate adapter' do
    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.google.com') do |faraday|
        faraday.adapter :excon
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 5

    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[1]['IsService'].must_equal '1'
    traces[1]['RemoteProtocol'].must_equal 'HTTP'
    traces[1]['RemoteHost'].must_equal 'www.google.com'
    traces[1]['ServiceArg'].must_equal '/?q=ruby_test_suite'
    traces[1]['HTTPMethod'].downcase.must_equal 'get'

    traces[2]['Layer'].must_equal 'faraday'
    traces[2]['Label'].must_equal 'info'
    traces[2]['HTTPStatus'].must_equal '200'

    traces[3]['Layer'].must_equal 'faraday'
    traces[3]['Label'].must_equal 'exit'
  end

  it 'should obey :collect_backtraces setting when true' do
    Oboe::Config[:faraday][:collect_backtraces] = true

    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.google.com') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_has_key(traces, 'faraday', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    Oboe::Config[:faraday][:collect_backtraces] = false

    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.google.com') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'faraday', 'Backtrace')
  end
end
