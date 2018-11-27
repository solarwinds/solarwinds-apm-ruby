# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

if RUBY_VERSION < '2.6.0'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest_helper'
require 'minitest/hooks/default'
require 'mocha/minitest'

$LOAD_PATH.unshift(File.join(File.dirname(File.dirname(__FILE__)), 'servers/grpc'))
require 'grpc_server_50051'

# uncomment to turn on logging from gRPC
# module GRPC
#   def self.logger
#     LOGGER
#   end
#
#   LOGGER = AppOpticsAPM.logger
# end

describe 'GRPC' do
  i_suck_and_my_tests_are_order_dependent!

  def start_server
    @pool_size = 6

    server_bt = AppOpticsAPM::Config[:grpc_server][:collect_backtraces]
    AppOpticsAPM::Config[:grpc_server][:collect_backtraces] = false

    @server = GRPC::RpcServer.new(pool_size: @pool_size)
    @server.add_http2_port("0.0.0.0:50051", :this_port_is_insecure)
    @server.handle(AddressService)
    @server_thread = Thread.new do
      begin
        @server.run_till_terminated
      rescue SystemExit, Interrupt
        @server.stop
      end
    end
    sleep 0.2
    AppOpticsAPM::Config[:grpc_server][:collect_backtraces] = server_bt
  end

  def stop_server
    sleep 0.2
    @server.stop
    @server_thread.join
  end

  def server_with_backtraces
    server_bt = AppOpticsAPM::Config[:grpc_server][:collect_backtraces]
    AppOpticsAPM::Config[:grpc_server][:collect_backtraces] = true

    server = GRPC::RpcServer.new(pool_size: 2)
    server.add_http2_port("0.0.0.0:50052", :this_port_is_insecure)
    server.handle(AddressService)
    server_thread = Thread.new do
      begin
        server.run_till_terminated
      rescue SystemExit, Interrupt
        server.stop
      end
    end
    sleep 0.2
    stub = Grpctest::TestService::Stub.new('localhost:50052', :this_channel_is_insecure)
    yield stub

    server.stop
    server_thread.join
    AppOpticsAPM::Config[:grpc_server][:collect_backtraces] = server_bt
  end

  before(:all) do
    @bt_client = AppOpticsAPM::Config[:grpc_client][:collect_backtraces]

    AppOpticsAPM::Config[:grpc_server][:collect_backtraces] = false
    start_server

    @null_msg = Grpctest::NullMessage.new
    @address_msg = Grpctest::Address.new(street: 'the_street', number:  123, town: 'Mission')
    @phone_msg = Grpctest::Phone.new(number: '12345678', type: 'mobile')

    @stub = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure)
    @unavailable = Grpctest::TestService::Stub.new('no_server', :this_channel_is_insecure)
    @no_time = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure, timeout: 0.1)

    @count = 30  ### this is used for stress tests to trigger a resource exhausted exception
  end

  before do
    AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = false
    clear_all_traces
  end

  after(:all) do
    AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = @bt_client
    stop_server
  end

  unless ['file', 'udp'].include?(ENV['APPOPTICS_REPORTER']) || AppopticsAPM::SDK.appoptics_ready?(10_000)
    puts "aborting!!! Agent not ready after 10 seconds"
    exit false
  end

  describe 'UNARY' do
    it 'should collect traces for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        res = @stub.unary(@address_msg)
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}

      traces.size.must_equal 4

      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/unary_1'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'unary_1'
      server_entry['URL'].must_equal             '/grpctest.TestService/unary_1'
      server_entry['HTTP-Host'].must_match       /127.0.0.1/

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.unary_1'

      traces.each { |tr| tr['GRPCMethodType'].must_equal 'UNARY' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
    end

    it 'should include backtraces for unary if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          stub.unary_1(@address_msg)
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        traces.size.must_equal 4

        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['Backtrace'].must_be_nil "Extra backtrace in trace"}
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| tr['Backtrace'].wont_be_nil "Backtrace missing"}
      end
    end

    # Both: Client Application cancelled the request
    it 'should report CANCELLED for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          @stub.unary_cancel(@null_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      if traces # no traces retrieved if sending them to the collector
        assert valid_edges?(traces), "Edges aren't valid"
        traces.size.must_equal 6
        assert_entry_exit(traces, 2)

        traces[0]['GRPCMethodType'].must_equal  'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| tr['Backtrace'].must_be_nil }
        traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
      end
    end

    # Both: Deadline expires before server returns status
    it 'should report DEADLINE_EXCEEDED for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          AppOpticsAPM::SDK.set_transaction_name('unary_deadline_exceeded')
          @stub.unary_long(@address_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      traces.size.must_equal 6
      assert_entry_exit(traces)
      assert valid_edges?(traces)

      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/unary_long'
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| tr['Backtrace'].must_be_nil }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }
    end

    # Client: Some data transmitted (e.g., request metadata written to TCP connection) before connection breaks
    # Server(not tested): Server shutting down
    it 'should report UNAVAILABLE for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          @unavailable.unary_unknown(@address_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      traces.size.must_equal 3
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| tr['Backtrace'].must_be_nil }
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    # Client: Error parsing returned status
    # Server: Application throws an exception (r something othe th returning a Status code to terminate an RPC)
    it 'should report UNKNOWN for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          @stub.unary_unknown(@address_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      traces.size.must_equal 6
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| tr['Backtrace'].must_be_nil }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    # Client: Response cardinality violation (streaming)*
    # Server: Method not found, compression not supported*, or request cardinality violation (streaming)*
    # * not tested
    it 'should report UNIMPLEMENTED for unary' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          @stub.unary_unimplemented(@null_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      traces.size.must_equal 6
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces.select { |tr| tr['Label'] =~ /exit|entry/}.each { |tr| tr['Backtrace'].must_be_nil }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    # Client: Error parsing response proto, keepalive watchdog times out, could not decompress (algorithm supported)
    # Server: Error parsing request proto, keepalive watchdog times out, could not decompress (algorithm supported)
    # * not tested
    it 'should report INTERNAL for unary' do
      skip # hard to provoke
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          @secure.unary_2(@null_msg)
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      traces.size.must_equal 6
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| tr['Backtrace'].must_be_nil }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'INTERNAL' }

      stop_secure_server
    end

    it 'sends metrics from the server for unary' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.unary_1', nil, is_a(Integer))
      @stub.unary_1(@address_msg)
    end
  end

  describe 'CLIENT_STREAMING' do
    it 'should collect traces for client_streaming' do
      AppopticsAPM::SDK.start_trace(:test) do
        @stub.client_stream([@phone_msg, @phone_msg])
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/client_stream'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'client_stream'
      server_entry['URL'].must_equal             '/grpctest.TestService/client_stream'

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.client_stream'

      traces.each { |tr| tr['GRPCMethodType'].must_equal  'CLIENT_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
      traces.each { |tr| tr['Backtrace'].must_be_nil }
    end

    it 'should include backtraces for client_streaming if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          stub.client_stream([@phone_msg, @phone_msg])
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces)

        traces.size.must_equal 4
        traces[0]['Spec'].must_equal            'rsc'
        traces[0]['RemoteURL'].must_equal       'grpc://localhost:50052/grpctest.TestService/client_stream'
        traces.each { |tr| tr['GRPCMethodType'].must_equal  'CLIENT_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
        traces.select { |tr| tr['Label'] == 'entry'}.each { |tr| tr['Backtrace'].must_be_nil "Found extra backtrace!" }
        traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['Backtrace'].wont_be_nil "Backtrace missing!" }
      end
    end

    it 'should report DEADLINE_EXCEEDED for client_streaming' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @no_time.client_stream_long(Array.new(5, @phone_msg))
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/client_stream_long'
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'CLIENT_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }
    end

    it 'should report CANCELLED for client_streaming' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.client_stream_cancel([@null_msg, @null_msg])
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
    end

    it 'should report UNAVAILABLE for client_streaming' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @unavailable.client_stream([@phone_msg, @phone_msg])
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNAVAILABLE' }
    end

    it 'should report UNKNOWN for client_streaming' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.client_stream_unknown([@address_msg, @address_msg])
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    it 'should report UNIMPLEMENTED for client_streaming' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.client_stream_unimplemented([@phone_msg, @phone_msg])
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    it 'sends metrics from the server for client_streaming' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.client_stream', nil, is_a(Integer))
      @stub.client_stream([@null_msg, @null_msg])
    end
  end # CLIENT_STREAMING

  describe 'SERVER_STREAMING return Enumerator' do
    it 'should collect traces for server_streaming returning enumerator' do
      AppopticsAPM::SDK.start_trace(:test) do
        res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
        res.each { |_| }
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/server_stream'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'server_stream'
      server_entry['URL'].must_equal             '/grpctest.TestService/server_stream'

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.server_stream'

      traces.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
      traces.each { |tr| tr['Backtrace'].must_be_nil }
    end

    it 'should add backtraces for server_streaming with enumerator if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          res = stub.server_stream(Grpctest::AddressId.new(id: 2))
          res.each { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        traces.size.must_equal 4

        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['Backtrace'].must_be_nil "Extra backtrace in trace" }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| tr['Backtrace'].wont_be_nil "Backtrace missing" }
      end
    end

    it 'should report CANCEL for server_streaming with enumerator' do
      AppopticsAPM::SDK.start_trace(:test) do
        res = @stub.server_stream_cancel(@null_msg)
        begin
          res.each { |_| }
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
    end

    it 'should report DEADLINE_EXCEEDED for server_streaming with enumerator' do
      AppopticsAPM::SDK.start_trace(:test) do
        begin
          res = @no_time.server_stream_long(@null_msg)
          res.each { |_| }
        rescue => _
        end
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }
    end

    it 'should report UNAVAILABLE for server_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @unavailable.server_stream(@null_msg)
          res.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces.size.must_equal 3
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNAVAILABLE' }
    end

    it 'should report UNKNOWN for server_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream_unknown(@address_msg)
          res.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}

      traces.size.must_equal 6
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    it 'should report UNIMPLEMENTED for server_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream_unimplemented(@null_msg)
          res.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    it 'sends metrics from the server for server_streaming with enumerator' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.server_stream', nil, is_a(Integer))
      res = @stub.server_stream(@null_msg)
      res.each { |_| }
      sleep 0.5
    end
  end # SERVER_STREAMING return Enumerator

  describe 'SERVER_STREAMING yield' do
    it 'should collect traces for server_streaming using block' do
      AppopticsAPM::SDK.start_trace(:test) do
        @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/server_stream'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'server_stream'
      server_entry['URL'].must_equal             '/grpctest.TestService/server_stream'

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.server_stream'

      traces.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
      traces.each { |tr| tr['Backtrace'].must_be_nil }
    end

    it 'should add backtraces for server_streaming using block if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        traces.size.must_equal 4

        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['Backtrace'].must_be_nil "Extra backtrace in trace"}
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| tr['Backtrace'].wont_be_nil "Backtrace missing" }
      end
    end

    it 'should report CANCEL for server_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.server_stream_cancel(@null_msg) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
    end

    it 'should report DEADLINE_EXCEEDED for server_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @no_time.server_stream_long(@null_msg) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }

    end

    it 'should report UNAVAILABLE for server_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @unavailable.server_stream(@null_msg) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces.size.must_equal 3
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNAVAILABLE' }
    end

    it 'should report UNKNOWN for server_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream_unknown(@address_msg)
          res.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    it 'should report UNIMPLEMENTED for server_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream_unimplemented(@null_msg) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'SERVER_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    it 'sends metrics from the server for server_streaming using block' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.server_stream', nil, is_a(Integer))
      @stub.server_stream(@null_msg) { |_| }
      sleep 0.5
    end
  end

  describe 'BIDI_STREAMING return Enumerator' do
    it 'should collect traces for for bidi_streaming with enumerator' do
      AppopticsAPM::SDK.start_trace(:test) do
        response = @stub.bidi_stream([@null_msg, @null_msg])
        response.each { |_| }
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/bidi_stream'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'bidi_stream'
      server_entry['URL'].must_equal             '/grpctest.TestService/bidi_stream'

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.bidi_stream'

      traces.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
      traces.each { |tr| tr['Backtrace'].must_be_nil }
    end

    it 'should add backtraces for bidi_streaming with enumerator if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          response = stub.bidi_stream([@null_msg, @null_msg])
          response.each { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        traces.size.must_equal 4

        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['Backtrace'].must_be_nil "Extra backtrace in trace"}
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| tr['Backtrace'].wont_be_nil "Backtrace missing" }
      end
    end

    it 'should report CANCEL for bidi_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          response = @stub.bidi_stream_cancel([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
          response.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          response = @no_time.bidi_stream_long([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
          response.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }
    end

    it 'should report UNAVAILABLE for bidi_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          response = @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
          response.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces.size.must_equal 3
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNAVAILABLE' }
    end

    it 'should report UNKNOWN for bidi_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          response = @stub.bidi_stream_unknown([@null_msg, @null_msg])
          response.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    it 'should report UNIMPLEMENTED for bidi_streaming with enumerator' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          response = @stub.bidi_stream_unimplemented([@null_msg, @null_msg])
          response.each { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}

      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    it 'sends metrics from the server for bidi_streaming with enumerator' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.bidi_stream', nil, is_a(Integer))
      response = @stub.bidi_stream([@null_msg, @null_msg])
      response.each { |_| }
    end
  end

  describe 'BIDI_STREAMING yield' do
    it 'should collect traces for bidi_streaming using block' do
      AppopticsAPM::SDK.start_trace(:test) do
        @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'grpc://localhost:50051/grpctest.TestService/bidi_stream'
      traces[0]['IsService'].must_equal       'True'

      server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
      server_entry['Spec'].must_equal            'grpc_server'
      server_entry['Controller'].must_equal      'AddressService'
      server_entry['Action'].must_equal          'bidi_stream'
      server_entry['URL'].must_equal             '/grpctest.TestService/bidi_stream'

      traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName'].must_equal 'AddressService.bidi_stream'

      traces.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'OK' }
      traces.each { |tr| tr['Backtrace'].must_be_nil }
    end

    it 'should add backtraces for bidi_streaming using block if configured' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      server_with_backtraces do |stub|
        AppopticsAPM::SDK.start_trace(:test) do
          stub.bidi_stream([@phone_msg, @phone_msg]) { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
        traces.size.must_equal 4

        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| tr['Backtrace'].must_be_nil "Extra backtrace in trace" }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| tr['Backtrace'].wont_be_nil "Backtraces missing" }
      end
    end

    it 'should report CANCEL for bidi_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.bidi_stream_cancel([@null_msg, @null_msg]) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'CANCELLED' }
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @no_time.bidi_stream_long([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'DEADLINE_EXCEEDED' }
    end

    it 'should report UNAVAILABLE for bidi_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 1)
      assert valid_edges?(traces)

      traces.size.must_equal 3
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNAVAILABLE' }
    end

    it 'should report UNKNOWN for bidi_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.bidi_stream_unknown([@null_msg, @null_msg]) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNKNOWN' }
    end

    it 'should report UNIMPLEMENTED for bidi_streaming using block' do
      begin
        AppopticsAPM::SDK.start_trace(:test) do
          @stub.bidi_stream_unimplemented([@null_msg, @null_msg]) { |_| }
        end
      rescue => _
      end

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, 2)
      assert valid_edges?(traces)

      traces.size.must_equal 6
      traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| tr['GRPCMethodType'].must_equal  'BIDI_STREAMING' }
      traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| tr['GRPCStatus'].must_equal 'UNIMPLEMENTED' }
    end

    it 'sends metrics from the server for bidi_streaming using block' do
      Oboe_metal::Span.expects(:createSpan).with('AddressService.bidi_stream', nil, is_a(Integer))
      @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
    end
  end

  describe "stressing the bidi server" do
    it "should report when stressed bidi gets RESOURCE_EXHAUSTED" do
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            AppopticsAPM::SDK.start_trace(:test) do
              @stub.bidi_stream(Array.new(200, @phone_msg)) { |_| }
            end
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      # TODO remove once now more debugging is needed
      # puts "  Exhausted request count: #{traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED/  }.size} out of #{@count}."

      assert_entry_exit(traces, nil, false)

      # we should get 2 client events for all calls, @pool_size * 2 events from the server, plus error events for exhaustion
      traces.size.must_equal 3*@count + @pool_size
      # only @pool_size calls get through, the others respond with RESOURCE_EXHAUSTED
      traces.select { |tr| tr['GRPCStatus'] == 'RESOURCE_EXHAUSTED' }.size.must_equal   @count - @pool_size
    end

    it "should work when stressed bidi gets cancelled" do
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            AppOpticsAPM::SDK.start_trace(:test) do
              @stub.bidi_stream_cancel(Array.new(200, @phone_msg)) { |_| }
            end
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, nil, false)

      cancelled = traces.select { |tr| tr['GRPCStatus'] =~ /CANCELLED/ }.size
      exhausted = traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED/ }.size
      (cancelled/2 + exhausted).must_equal @count

      traces.size.must_equal @count*6 - exhausted*3
    end

    it "should work when stressed bidi is unavailable" do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            AppopticsAPM::SDK.start_trace(:test) do
              @unavailable.bidi_stream(Array.new(200, @phone_msg)) { |_| }
            end
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}
      assert_entry_exit(traces, @count, false)

      traces.size.must_equal 3*@count

      traces.select { |tr| tr['GRPCMethodType'] == 'BIDI_STREAMING' }.size.must_equal 2*@count
      traces.select { |tr| !tr['Backtrace'].nil? }.size.must_equal                    2*@count
      traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED|UNAVAILABLE/ }.size.must_equal @count
    end


    it "should raise and tag varying exceptions" do
      threads = []
      (3*@count).times do
        threads << Thread.new do
          begin
            AppopticsAPM::SDK.start_trace(:test) do
              @stub.bidi_stream_varying(Array.new(20, @phone_msg)) { |_| }
            end
          rescue => _
          end
        end
      end

      sleep 0.5
      threads.each { |thd| thd.join; }

      traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test'}

      assert_entry_exit(traces, nil, false)

      groups = traces_group(traces)
      pairs = groups.map { |arr| arr.select { |a| a['Label'] == 'exit' } }
      pairs.each { |pair| assert_same_status(pair) }
    end

    def traces_group(traces)
      entries = traces.select { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
      groups = []
      entries.each_with_index do |tr, i|
        groups[i] = [tr]
        while tr_new = traces.find { |tr2| tr2['Edge'] == groups[i].last['X-Trace'][42..-3] }
          groups[i] << tr_new
        end
      end
      groups
    end

    def assert_same_status(pair)
      if pair[0]['GRPCStatus'] == 'RESOURCE_EXHAUSTED'
        refute pair[1], "there should not be a server event for RESOURCE_EXHAUSTED"
      else
        assert pair[1], "no server exit event found for #{pair[0]['GRPCStatus']}"
        assert_equal pair[0]['GRPCStatus'], pair[1]['GRPCStatus']
      end
    end
  end
end
end