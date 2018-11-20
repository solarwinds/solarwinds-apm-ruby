# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack'

describe "Typhoeus" do
  before do
    clear_all_traces
    @collect_backtraces = AppOpticsAPM::Config[:typhoeus][:collect_backtraces]
    @log_args = AppOpticsAPM::Config[:typhoeus][:log_args]
  end

  after do
    AppOpticsAPM::Config[:typhoeus][:collect_backtraces] = @collect_backtraces
    AppOpticsAPM::Config[:typhoeus][:log_args] = @log_args
  end

  it 'Typhoeus should be defined and ready' do
    defined?(::Typhoeus::Request::Operations).wont_match nil
  end

  it 'Typhoeus should have appoptics_apm methods defined' do
    [ :run_with_appoptics ].each do |m|
      ::Typhoeus::Request::Operations.method_defined?(m).must_equal true
    end
  end

  it 'should trace a typhoeus request' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[4]['HTTPMethod'].must_equal 'GET'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus request to an uninstrumented app' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("http://127.0.0.1:8110/?blah=1")
    end

    traces = get_all_traces
    traces.count.must_equal 4

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Label'].must_equal 'exit'
    traces[2]['Spec'].must_equal 'rsc'
    traces[2]['IsService'].must_equal 1
    traces[2]['RemoteURL'].must_equal 'http://127.0.0.1:8110/?blah=1'
    traces[2]['HTTPMethod'].must_equal 'GET'
    traces[2]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus POST request' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.post("127.0.0.1:8101/",
                    :body => { :key => "appoptics-ruby-fake", :content => "appoptics-ruby repo test suite"})
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
    traces[4]['HTTPMethod'].must_equal 'POST'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus PUT request' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.put("http://127.0.0.1:8101/",
                   :body => { :key => "appoptics-ruby-fake", :content => "appoptics-ruby repo test suite"})
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[4]['HTTPMethod'].must_equal 'PUT'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus DELETE request' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.delete("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[4]['HTTPMethod'].must_equal 'DELETE'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus HEAD request' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.head("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[4]['HTTPMethod'].must_equal 'HEAD'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus GET request to an instr\'d app' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
    traces[4]['Spec'].must_equal 'rsc'
    traces[4]['IsService'].must_equal 1
    traces[4]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
    traces[4]['HTTPMethod'].must_equal 'GET'
    traces[4]['HTTPStatus'].must_equal 200
  end

  it 'should trace a typhoeus GET request with DNS error' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("thisdomaindoesntexisthopefully.asdf/products/appoptics_apm/")
    end

    traces = get_all_traces
    traces.count.must_equal 5

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOpticsAPM::Config[:typhoeus][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Spec'].must_equal 'error'
    traces[2]['Label'].must_equal 'error'
    traces[2]['ErrorClass'].must_equal 'TyphoeusError'
    traces[2].must_include('ErrorMsg')
    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 1

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'exit'
    traces[3]['Spec'].must_equal 'rsc'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteURL'].casecmp('http://thisdomaindoesntexisthopefully.asdf/products/appoptics_apm/').must_equal 0
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal 0
  end

  it 'should trace parallel typhoeus requests' do
    AppOpticsAPM::API.start_trace('typhoeus_test') do
      hydra = Typhoeus::Hydra.hydra

      first_request  = Typhoeus::Request.new("127.0.0.1:8101/products/appoptics_apm/")
      second_request = Typhoeus::Request.new("127.0.0.1:8101/products/")
      third_request  = Typhoeus::Request.new("127.0.0.1:8101/")

      hydra.queue first_request
      hydra.queue second_request
      hydra.queue third_request

      hydra.run
    end

    traces = get_all_traces
    traces.count.must_equal 10

    valid_edges?(traces, false).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus_hydra'
    traces[1]['Label'].must_equal 'entry'
    traces[1]['Async'].must_equal 1

    traces[8]['Layer'].must_equal 'typhoeus_hydra'
    traces[8]['Label'].must_equal 'exit'
  end

  it 'should obey :log_args setting when true' do
    AppOpticsAPM::Config[:typhoeus][:log_args] = true

    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    traces.count.must_equal 6
    traces[4]['RemoteURL'].casecmp('http://127.0.0.1:8101/?blah=1').must_equal 0
  end

  it 'should obey :log_args setting when false' do
    AppOpticsAPM::Config[:typhoeus][:log_args] = false

    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    traces.count.must_equal 6
    traces[4]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
  end

  it 'should obey :collect_backtraces setting when true' do
    AppOpticsAPM::Config[:typhoeus][:collect_backtraces] = true

    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    traces.count.must_equal 6
    layer_has_key(traces, 'typhoeus', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    AppOpticsAPM::Config[:typhoeus][:collect_backtraces] = false

    AppOpticsAPM::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 6
    layer_doesnt_have_key(traces, 'typhoeus', 'Backtrace')
  end
end
