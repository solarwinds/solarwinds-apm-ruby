require 'minitest_helper'

describe Oboe::Inst::TyphoeusRequestOps do
  before do
    clear_all_traces
    @collect_backtraces = Oboe::Config[:typhoeus][:collect_backtraces]
  end

  after do
    Oboe::Config[:typhoeus][:collect_backtraces] = @collect_backtraces
  end

  it 'Typhoeus should be defined and ready' do
    defined?(::Typhoeus::Request::Operations).wont_match nil
  end

  it 'Typhoeus should have oboe methods defined' do
    [ :run_with_oboe ].each do |m|
      ::Typhoeus::Request::Operations.method_defined?(m).must_equal true
    end
  end

  it 'should trace a typhoeus request' do
    Oboe::API.start_trace('typhoeus_test') do
      Typhoeus.get("www.appneta.com/products/traceview/")
    end

    traces = get_all_traces
    traces.count.must_equal 5

    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:typhoeus][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Label'].must_equal 'info'
    traces[2]['IsService'].must_equal '1'
    traces[2]['RemoteProtocol'].must_equal 'http'
    traces[2]['RemoteHost'].must_equal 'www.appneta.com'
    traces[2]['ServiceArg'].must_equal '/products/traceview/'
    traces[2]['HTTPMethod'].must_equal 'get'
    traces[2]['HTTPStatus'].must_equal '200'

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus request with error' do
    Oboe::API.start_trace('typhoeus_test') do
      Typhoeus.get("thisdomaindoesntexisthopefully.asdf/products/traceview/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal Oboe::Config[:typhoeus][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Label'].must_equal 'error'

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'info'
    traces[3]['IsService'].must_equal '1'
    traces[3]['RemoteProtocol'].must_equal 'http'
    traces[3]['RemoteHost'].must_equal 'thisdomaindoesntexisthopefully.asdf'
    traces[3]['ServiceArg'].must_equal '/products/traceview/'
    traces[3]['HTTPMethod'].must_equal 'get'
    traces[3]['HTTPStatus'].must_equal '0'

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'info'

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
  end

  it 'should trace parallel typhoeus requests' do
    Oboe::API.start_trace('typhoeus_test') do
      hydra = Typhoeus::Hydra.hydra

      first_request  = Typhoeus::Request.new("www.appneta.com/products/traceview/")
      second_request = Typhoeus::Request.new("www.appneta.com/products/")
      third_request  = Typhoeus::Request.new("www.curlmyip.com")

      hydra.queue first_request
      hydra.queue second_request
      hydra.queue third_request

      hydra.run
    end

    traces = get_all_traces
    traces.count.must_equal 4

    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus_hydra'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'typhoeus_hydra'
    traces[2]['Label'].must_equal 'exit'
  end

  it 'should obey :collect_backtraces setting when true' do
    Oboe::Config[:typhoeus][:collect_backtraces] = true

    Oboe::API.start_trace('typhoeus_test') do
      Typhoeus.get("www.appneta.com/products/traceview/")
    end

    traces = get_all_traces
    layer_has_key(traces, 'typhoeus', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    Oboe::Config[:typhoeus][:collect_backtraces] = false

    Oboe::API.start_trace('typhoeus_test') do
      Typhoeus.get("www.appneta.com/products/traceview/")
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'typhoeus', 'Backtrace')
  end
end
