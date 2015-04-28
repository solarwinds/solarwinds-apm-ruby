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
      conn = Faraday.new(:url => 'http://www.gameface.in') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/games?q=1'
      response.headers["x-trace"].wont_match nil
    end

    traces = get_all_traces
    traces.count.must_equal 8

    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteProtocol'].must_equal 'HTTP'
    traces[3]['RemoteHost'].must_equal 'www.gameface.in'
    traces[3]['ServiceArg'].must_equal '/games?q=1'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'net-http'
    traces[4]['Label'].must_equal 'exit'

    traces[6]['Layer'].must_equal 'faraday'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday request' do
    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.curlmyip.de') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/?q=ruby_test_suite'
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteProtocol'].must_equal 'HTTP'
    traces[3]['RemoteHost'].must_equal 'www.curlmyip.de'
    traces[3]['ServiceArg'].must_equal '/?q=ruby_test_suite'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'net-http'
    traces[4]['Label'].must_equal 'exit'

    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'info'

    traces[6]['Layer'].must_equal 'faraday'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday alternate request method' do
    Oboe::API.start_trace('faraday_test') do
      Faraday.get('http://www.curlmyip.de', {:a => 1})
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[3]['Layer'].must_equal 'net-http'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteProtocol'].must_equal 'HTTP'
    traces[3]['RemoteHost'].must_equal 'www.curlmyip.de'
    traces[3]['ServiceArg'].must_equal '/?a=1'
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal '200'

    traces[4]['Layer'].must_equal 'net-http'
    traces[4]['Label'].must_equal 'exit'

    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'info'

    traces[6]['Layer'].must_equal 'faraday'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a Faraday with an alternate adapter' do
    Oboe::API.start_trace('faraday_test') do
      conn = Faraday.new(:url => 'http://www.curlmyip.de') do |faraday|
        faraday.adapter :excon
      end
      response = conn.get '/?q=1'
    end

    traces = get_all_traces
    traces.count.must_equal 7

    valid_edges?(traces)
    validate_outer_layers(traces, 'faraday_test')

    traces[1]['Layer'].must_equal 'faraday'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:faraday][:collect_backtraces]

    traces[2]['Layer'].must_equal 'excon'
    traces[2]['Label'].must_equal 'entry'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteProtocol'].must_equal 'HTTP'
    traces[2]['RemoteHost'].must_equal 'www.curlmyip.de'
    traces[2]['ServiceArg'].must_equal '/?q=1'
    traces[2]['HTTPMethod'].must_equal 'GET'

    traces[3]['Layer'].must_equal 'excon'
    traces[3]['Label'].must_equal 'exit'
    traces[3]['HTTPStatus'].must_equal 200

    traces[4]['Layer'].must_equal 'faraday'
    traces[4]['Label'].must_equal 'info'
    unless RUBY_VERSION < '1.9.3'
      # FIXME: Ruby 1.8 is reporting an object instance instead of
      # an array
      traces[4]['Middleware'].must_equal '[Faraday::Adapter::Excon]'
    end

    traces[5]['Layer'].must_equal 'faraday'
    traces[5]['Label'].must_equal 'exit'
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
