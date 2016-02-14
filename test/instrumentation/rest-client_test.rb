# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

if RUBY_VERSION >= '1.9.3'
  describe "RestClient" do
    before do
      clear_all_traces
      @collect_backtraces = TraceView::Config[:rest_client][:collect_backtraces]
    end

    after do
      TraceView::Config[:rest_client][:collect_backtraces] = @collect_backtraces
    end

    it 'RestClient should be defined and ready' do
      defined?(::RestClient).wont_match nil
    end

    it 'RestClient should have traceview methods defined' do
      [ :execute_with_traceview ].each do |m|
        ::RestClient::Request.method_defined?(m).must_equal true
      end
    end

    it "should report rest-client version in __Init" do
      init_kvs = ::TraceView::Util.build_init_report

      init_kvs.key?('Ruby.rest-client.Version').must_equal true
      init_kvs['Ruby.rest-client.Version'].must_equal ::RestClient::VERSION
    end

    it "should trace a request to an instr'd app" do
      response = nil

      TraceView::API.start_trace('rest_client_test') do
        response = RestClient.get 'http://127.0.0.1:8101/'
      end

      traces = get_all_traces
      traces.count.must_equal 10

      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'net-http'
      traces[2]['Label'].must_equal 'entry'

      traces[6]['Layer'].must_equal 'net-http'
      traces[6]['Label'].must_equal 'info'
      traces[6]['IsService'].must_equal 1
      traces[6]['RemoteProtocol'].must_equal 'HTTP'
      traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[6]['ServiceArg'].must_equal '/'
      traces[6]['HTTPMethod'].must_equal 'GET'
      traces[6]['HTTPStatus'].must_equal "200"
      traces[6].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[7]['Layer'].must_equal 'net-http'
      traces[7]['Label'].must_equal 'exit'

      traces[8]['Layer'].must_equal 'rest-client'
      traces[8]['Label'].must_equal 'exit'

      response.headers.key?(:x_trace).wont_equal nil
      xtrace = response.headers[:x_trace]

      # FIXME: Under JRuby works in live stacks but broken in tests.
      # Need to investigate
      unless defined?(JRUBY_VERSION)
        TraceView::XTrace.valid?(xtrace).must_equal true
      end
    end

    it 'should trace a raw GET request' do
      response = nil

      TraceView::API.start_trace('rest_client_test') do
        response = RestClient.get 'http://127.0.0.1:8101/?a=1'
      end

      traces = get_all_traces
      traces.count.must_equal 10

      # FIXME: We need to switch from making external calls to an internal test
      # stack instead so we can validate cross-app traces.
      # valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'net-http'
      traces[2]['Label'].must_equal 'entry'

      traces[6]['Layer'].must_equal 'net-http'
      traces[6]['Label'].must_equal 'info'
      traces[6]['IsService'].must_equal 1
      traces[6]['RemoteProtocol'].must_equal 'HTTP'
      traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[6]['ServiceArg'].must_equal '/?a=1'
      traces[6]['HTTPMethod'].must_equal 'GET'
      traces[6]['HTTPStatus'].must_equal "200"
      traces[6].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[7]['Layer'].must_equal 'net-http'
      traces[7]['Label'].must_equal 'exit'

      traces[8]['Layer'].must_equal 'rest-client'
      traces[8]['Label'].must_equal 'exit'
    end

    it 'should trace a raw POST request' do
      response = nil

      TraceView::API.start_trace('rest_client_test') do
        response = RestClient.post 'http://127.0.0.1:8101/', :param1 => 'one', :nested => { :param2 => 'two' }
      end

      traces = get_all_traces
      traces.count.must_equal 10

      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'net-http'
      traces[2]['Label'].must_equal 'entry'

      traces[6]['Layer'].must_equal 'net-http'
      traces[6]['Label'].must_equal 'info'
      traces[6]['IsService'].must_equal 1
      traces[6]['RemoteProtocol'].must_equal 'HTTP'
      traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[6]['ServiceArg'].must_equal '/'
      traces[6]['HTTPMethod'].must_equal 'POST'
      traces[6]['HTTPStatus'].must_equal "200"
      traces[6].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[7]['Layer'].must_equal 'net-http'
      traces[7]['Label'].must_equal 'exit'

      traces[8]['Layer'].must_equal 'rest-client'
      traces[8]['Label'].must_equal 'exit'
    end

    it 'should trace a ActiveResource style GET request' do
      response = nil

      TraceView::API.start_trace('rest_client_test') do
        resource = RestClient::Resource.new 'http://127.0.0.1:8101/?a=1'
        response = resource.get
      end

      traces = get_all_traces
      traces.count.must_equal 10

      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'net-http'
      traces[2]['Label'].must_equal 'entry'

      traces[6]['Layer'].must_equal 'net-http'
      traces[6]['Label'].must_equal 'info'
      traces[6]['IsService'].must_equal 1
      traces[6]['RemoteProtocol'].must_equal 'HTTP'
      traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[6]['ServiceArg'].must_equal '/?a=1'
      traces[6]['HTTPMethod'].must_equal 'GET'
      traces[6]['HTTPStatus'].must_equal "200"
      traces[6].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[7]['Layer'].must_equal 'net-http'
      traces[7]['Label'].must_equal 'exit'

      traces[8]['Layer'].must_equal 'rest-client'
      traces[8]['Label'].must_equal 'exit'
    end

    it 'should trace requests with redirects' do
      response = nil

      TraceView::API.start_trace('rest_client_test') do
        resource = RestClient::Resource.new 'http://127.0.0.1:8101/redirectme?redirect_test'
        response = resource.get
      end

      traces = get_all_traces
      traces.count.must_equal 18

      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'net-http'
      traces[2]['Label'].must_equal 'entry'

      traces[6]['Layer'].must_equal 'net-http'
      traces[6]['Label'].must_equal 'info'
      traces[6]['IsService'].must_equal 1
      traces[6]['RemoteProtocol'].must_equal 'HTTP'
      traces[6]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[6]['ServiceArg'].must_equal '/redirectme?redirect_test'
      traces[6]['HTTPMethod'].must_equal 'GET'
      traces[6]['HTTPStatus'].must_equal "301"
      traces[6].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[7]['Layer'].must_equal 'net-http'
      traces[7]['Label'].must_equal 'exit'

      traces[8]['Layer'].must_equal 'rest-client'
      traces[8]['Label'].must_equal 'entry'

      traces[9]['Layer'].must_equal 'net-http'
      traces[9]['Label'].must_equal 'entry'

      traces[13]['Layer'].must_equal 'net-http'
      traces[13]['Label'].must_equal 'info'
      traces[13]['IsService'].must_equal 1
      traces[13]['RemoteProtocol'].must_equal 'HTTP'
      traces[13]['RemoteHost'].must_equal '127.0.0.1:8101'
      traces[13]['ServiceArg'].must_equal '/'
      traces[13]['HTTPMethod'].must_equal 'GET'
      traces[13]['HTTPStatus'].must_equal "200"
      traces[13].key?('Backtrace').must_equal TraceView::Config[:nethttp][:collect_backtraces]

      traces[14]['Layer'].must_equal 'net-http'
      traces[14]['Label'].must_equal 'exit'

      traces[15]['Layer'].must_equal 'rest-client'
      traces[15]['Label'].must_equal 'exit'

      traces[16]['Layer'].must_equal 'rest-client'
      traces[16]['Label'].must_equal 'exit'
    end

    it 'should trace and capture raised exceptions' do
      TraceView::API.start_trace('rest_client_test') do
        begin
          RestClient.get 'http://s6KTgaz7636z/resource'
        rescue
          # We want an exception to be raised.  Just don't raise
          # it beyond this point.
        end
      end

      traces = get_all_traces
      traces.count.must_equal 5

      valid_edges?(traces).must_equal true
      validate_outer_layers(traces, 'rest_client_test')

      traces[1]['Layer'].must_equal 'rest-client'
      traces[1]['Label'].must_equal 'entry'

      traces[2]['Layer'].must_equal 'rest-client'
      traces[2]['Label'].must_equal 'error'
      traces[2]['ErrorClass'].must_equal 'SocketError'
      traces[2].key?('ErrorMsg').must_equal true
      traces[2].key?('Backtrace').must_equal true

      traces[3]['Layer'].must_equal 'rest-client'
      traces[3]['Label'].must_equal 'exit'
    end

    it 'should obey :collect_backtraces setting when true' do
      TraceView::Config[:rest_client][:collect_backtraces] = true

      TraceView::API.start_trace('rest_client_test') do
        RestClient.get('http://127.0.0.1:8101/', {:a => 1})
      end

      traces = get_all_traces
      layer_has_key(traces, 'rest-client', 'Backtrace')
    end

    it 'should obey :collect_backtraces setting when false' do
      TraceView::Config[:rest_client][:collect_backtraces] = false

      TraceView::API.start_trace('rest_client_test') do
        RestClient.get('http://127.0.0.1:8101/', {:a => 1})
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'rest-client', 'Backtrace')
    end
  end
end
