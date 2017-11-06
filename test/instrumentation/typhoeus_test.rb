# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'rack'

describe "Typhoeus" do
  before do
    clear_all_traces
    @collect_backtraces = AppOptics::Config[:typhoeus][:collect_backtraces]
    @log_args = AppOptics::Config[:typhoeus][:log_args]
  end

  after do
    AppOptics::Config[:typhoeus][:collect_backtraces] = @collect_backtraces
    AppOptics::Config[:typhoeus][:log_args] = @log_args
  end

  it 'Typhoeus should be defined and ready' do
    defined?(::Typhoeus::Request::Operations).wont_match nil
  end

  it 'Typhoeus should have appoptics methods defined' do
    [ :run_with_appoptics ].each do |m|
      ::Typhoeus::Request::Operations.method_defined?(m).must_equal true
    end
  end

  it 'should trace a typhoeus request' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus POST request' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.post("127.0.0.1:8101/",
                    :body => { :key => "appoptics-ruby-fake", :content => "appoptics-ruby repo test suite"})
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
    traces[5]['HTTPMethod'].must_equal 'POST'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus PUT request' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.put("http://127.0.0.1:8101/",
                    :body => { :key => "appoptics-ruby-fake", :content => "appoptics-ruby repo test suite"})
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'PUT'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus DELETE request' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.delete("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'DELETE'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus HEAD request' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.head("http://127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'HEAD'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus GET request to an instr\'d app' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/")
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[5]['Layer'].must_equal 'typhoeus'
    traces[5]['Label'].must_equal 'info'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal 200

    traces[6]['Layer'].must_equal 'typhoeus'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a typhoeus GET request with DNS error' do
    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("thisdomaindoesntexisthopefully.asdf/products/appoptics/")
    end

    traces = get_all_traces
    traces.count.must_equal 6

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus'
    traces[1].key?('Backtrace').must_equal AppOptics::Config[:typhoeus][:collect_backtraces]

    traces[2]['Layer'].must_equal 'typhoeus'
    traces[2]['Label'].must_equal 'error'

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'info'
    traces[3]['IsService'].must_equal 1
    traces[3]['RemoteURL'].casecmp('http://thisdomaindoesntexisthopefully.asdf/products/appoptics/').must_equal 0
    traces[3]['HTTPMethod'].must_equal 'GET'
    traces[3]['HTTPStatus'].must_equal 0

    traces[3]['Layer'].must_equal 'typhoeus'
    traces[3]['Label'].must_equal 'info'

    traces[4]['Layer'].must_equal 'typhoeus'
    traces[4]['Label'].must_equal 'exit'
  end

  it 'should trace parallel typhoeus requests' do
    AppOptics::API.start_trace('typhoeus_test') do
      hydra = Typhoeus::Hydra.hydra

      first_request  = Typhoeus::Request.new("127.0.0.1:8101/products/appoptics/")
      second_request = Typhoeus::Request.new("127.0.0.1:8101/products/")
      third_request  = Typhoeus::Request.new("127.0.0.1:8101/")

      hydra.queue first_request
      hydra.queue second_request
      hydra.queue third_request

      hydra.run
    end

    traces = get_all_traces
    traces.count.must_equal 13

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'typhoeus_test')

    traces[1]['Layer'].must_equal 'typhoeus_hydra'
    traces[1]['Label'].must_equal 'entry'

    traces[11]['Layer'].must_equal 'typhoeus_hydra'
    traces[11]['Label'].must_equal 'exit'
  end

  it 'should obey :log_args setting when true' do
    AppOptics::Config[:typhoeus][:log_args] = true

    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    traces[5]['RemoteURL'].casecmp('http://127.0.0.1:8101/?blah=1').must_equal 0
  end

  it 'should obey :log_args setting when false' do
    AppOptics::Config[:typhoeus][:log_args] = false

    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    traces[5]['RemoteURL'].casecmp('http://127.0.0.1:8101/').must_equal 0
  end

  it 'should obey :collect_backtraces setting when true' do
    AppOptics::Config[:typhoeus][:collect_backtraces] = true

    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/?blah=1")
    end

    traces = get_all_traces
    layer_has_key(traces, 'typhoeus', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    AppOptics::Config[:typhoeus][:collect_backtraces] = false

    AppOptics::API.start_trace('typhoeus_test') do
      Typhoeus.get("127.0.0.1:8101/")
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'typhoeus', 'Backtrace')
  end
end
