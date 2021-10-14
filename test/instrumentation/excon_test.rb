# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

describe 'ExconTest' do
  include Rack::Test::Methods

  def app
    SinatraSimple
  end

  it 'Excon should have AppOptics instrumentation prepended' do
    _(Excon::Connection.ancestors).must_include(AppOpticsAPM::Inst::ExconConnection)
  end

  it 'must_return_xtrace_header' do
    skip if defined?(JRUBY_VERSION)

    clear_all_traces
    get "/"
    xtrace = last_response['X-Trace']

    # Rack response header management under JRUBY.
    assert xtrace
    assert AppOpticsAPM::XTrace.valid?(xtrace)
  end

   it 'reports_version_init' do
    init_kvs = ::AppOpticsAPM::Util.build_init_report
    assert_equal ::Excon::VERSION, init_kvs['Ruby.excon.Version']
  end

   it 'class_get_request' do
    clear_all_traces

    AppOpticsAPM::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/')
    end

    traces = get_all_traces
    assert_equal 6, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'rsc',                    traces[1]['Spec']
    assert_equal 1,                        traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']
    assert_equal 'GET',                    traces[1]['HTTPMethod']

    assert_equal 'excon',     traces[4]['Layer']
    assert_equal 'exit',      traces[4]['Label']
    assert_equal 200,         traces[4]['HTTPStatus']
    assert traces[4].key?('Backtrace')
  end

   it 'cross_app_tracing' do
    clear_all_traces

    AppOpticsAPM::API.start_trace('excon_tests') do
      response = Excon.get('http://127.0.0.1:8101/?blah=1')
      xtrace = response.headers['X-Trace']

      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)
    end

    traces = get_all_traces
    assert_equal 6, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'rsc',                           traces[1]['Spec']
    assert_equal 1,                               traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8101/?blah=1', traces[1]['RemoteURL']
    assert_equal 'GET',        traces[1]['HTTPMethod']
    assert_equal 200,          traces[4]['HTTPStatus']
    assert traces[4].key?('Backtrace')
  end

   it 'cross_uninstr_app_tracing' do
    clear_all_traces

    AppOpticsAPM::API.start_trace('excon_tests') do
      response = Excon.get('http://127.0.0.1:8110/?blah=1')
      refute response.headers['X-Trace']
    end

    traces = get_all_traces
    assert_equal 4, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces), "Invalid edge in traces"

    assert_equal 'rsc',                           traces[1]['Spec']
    assert_equal 1,                               traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8110/?blah=1', traces[1]['RemoteURL']
    assert_equal 'GET',                           traces[1]['HTTPMethod']

    assert_equal 200,          traces[2]['HTTPStatus']
    assert traces[2].key?('Backtrace')
  end


   it 'persistent_requests' do
    # Persistence was adding in 0.31.0
    skip if Excon::VERSION < '0.31.0'

    clear_all_traces

    AppOpticsAPM::API.start_trace('excon_tests') do
      connection = Excon.new('http://127.0.0.1:8101/') # non-persistent by default
      connection.get # socket established, then closed
      connection.get(:persistent => true) # socket established, left open
      connection.get # socket reused, then closed
    end

    traces = get_all_traces
    assert_equal 14, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'rsc',                    traces[1]['Spec']
    assert_equal 1,                        traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']
    assert_equal 'GET',                    traces[1]['HTTPMethod']

    assert_equal 200,                      traces[4]['HTTPStatus']
    assert traces[4].key?('Backtrace')

    assert_equal 'rsc',                    traces[5]['Spec']
    assert_equal 1,                        traces[5]['IsService']
    assert_equal 'http://127.0.0.1:8101/', traces[5]['RemoteURL']
    assert_equal 'GET',                    traces[5]['HTTPMethod']

    assert_equal 200,                      traces[8]['HTTPStatus']

    assert_equal 'rsc',                    traces[9]['Spec']
    assert_equal 1,                        traces[9]['IsService']
    assert_equal 'http://127.0.0.1:8101/', traces[9]['RemoteURL']

    assert_equal 'GET',                    traces[9]['HTTPMethod']

    assert_equal 200,                      traces[12]['HTTPStatus']
    assert traces[12].key?('Backtrace')
  end

   it 'pipelined_requests' do
    clear_all_traces

    AppOpticsAPM::API.start_trace('excon_tests') do
      connection = Excon.new('http://127.0.0.1:8101/')
      connection.requests([{:method => :get}, {:method => :put}])
    end

    traces = get_all_traces
    assert_equal 8, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 'rsc',                    traces[1]['Spec']
    assert_equal 1,                        traces[1]['IsService']
    assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']
    assert_equal 'true',                   traces[1]['Pipeline']
    assert_equal 'GET,PUT',                traces[1]['HTTPMethods']
    assert traces[6].key?('Backtrace')

    assert_equal '200,200',                traces[6]['HTTPStatuses']
  end

   it 'requests_with_errors' do
    clear_all_traces

    begin
      AppOpticsAPM::API.start_trace('excon_tests') do
        Excon.get('http://asfjalkljkaljf/')
      end
    rescue
    end

    traces = get_all_traces
    assert_equal 5, traces.count
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces), "Invalid edge in traces"

    assert_equal 'rsc',                       traces[1]['Spec']
    assert_equal 1,                           traces[1]['IsService']
    assert_equal 'http://asfjalkljkaljf:80/', traces[1]['RemoteURL']

    assert_equal 'excon',                     traces[2]['Layer']
    assert_equal 'error',                     traces[2]['Spec']
    assert_equal 'error',                     traces[2]['Label']
    assert_match /Excon::.*Socket/,           traces[2]['ErrorClass']
    assert traces[2].key?('ErrorMsg')
    assert traces[2].key?('Backtrace')
    assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

    assert_equal 'excon',                     traces[3]['Layer']
    assert_equal 'exit',                      traces[3]['Label']
    assert traces[3].key?('Backtrace')
  end

   it 'obey_log_args_when_false' do
    @log_args = AppOpticsAPM::Config[:excon][:log_args]
    clear_all_traces

    AppOpticsAPM::Config[:excon][:log_args] = false

    AppOpticsAPM::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 6, traces.count
    assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']

    AppOpticsAPM::Config[:excon][:log_args] = @log_args
  end

   it 'obey_log_args_when_true' do
    @log_args = AppOpticsAPM::Config[:excon][:log_args]
    clear_all_traces

    AppOpticsAPM::Config[:excon][:log_args] = true

    AppOpticsAPM::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?blah=1')
    end

    traces = get_all_traces
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 6, traces.count
    assert_equal 'http://127.0.0.1:8101/?blah=1', traces[1]['RemoteURL']

    AppOpticsAPM::Config[:excon][:log_args] = @log_args
  end

   it 'obey_log_args_when_true_and_using_hash' do
    @log_args = AppOpticsAPM::Config[:excon][:log_args]
    clear_all_traces

    AppOpticsAPM::Config[:excon][:log_args] = true

    AppOpticsAPM::API.start_trace('excon_tests') do
      Excon.get('http://127.0.0.1:8101/?', :query => { :blah => 1 })
    end

    traces = get_all_traces
    validate_outer_layers(traces, "excon_tests")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    assert_equal 6, traces.count
    assert_equal 'http://127.0.0.1:8101/?blah=1', traces[1]['RemoteURL']

    AppOpticsAPM::Config[:excon][:log_args] = @log_args
  end
end

