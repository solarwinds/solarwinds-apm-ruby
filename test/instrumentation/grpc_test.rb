# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest_helper'
require 'minitest/hooks/default'
require 'mocha/minitest'

if defined? GRPC
  $LOAD_PATH.unshift(File.join(File.dirname(File.dirname(__FILE__)), 'servers/grpc'))
  require 'grpc_server_50051'

  # uncomment to turn on logging from gRPC
  # module GRPC
  #   def self.logger
  #     LOGGER
  #   end
  #
  #   AppOpticsAPM.logger.level = Logger::DEBUG
  #   LOGGER = AppOpticsAPM.logger
  # end

  describe 'GRPC' do

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
      @address_msg = Grpctest::Address.new(street: 'the_street', number: 123, town: 'Mission')
      @phone_msg = Grpctest::Phone.new(number: '12345678', type: 'mobile')

      @stub = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure)
      @unavailable = Grpctest::TestService::Stub.new('no_server', :this_channel_is_insecure)
      @no_time = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure, timeout: 0.1)

      @count = 30 ### this is used for stress tests to trigger a resource exhausted exception

      @trace_00 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
      @trace_01 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
    end

    before do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = false
      clear_all_traces
    end

    after(:all) do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = @bt_client
      stop_server
    end

    unless ['file', 'udp'].include?(ENV['APPOPTICS_REPORTER']) || AppOpticsAPM::SDK.appoptics_ready?(10_000)
      puts "aborting!!! Agent not ready after 10 seconds"
      exit false
    end

    describe 'UNARY' do
      it 'should collect traces for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          res = @stub.unary(@address_msg)
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }

        _(traces.size).must_equal 4

        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/unary'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'unary'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/unary'
        _(server_entry['HTTP-Host']).must_match       /127.0.0.1/

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.unary'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'UNARY' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
      end

      it 'should include backtraces for unary if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            stub.unary(@address_msg)
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          _(traces.size).must_equal 4

          traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['Backtrace']).must_be_nil "Extra backtrace in trace" }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtrace missing" }
        end
      end

      it 'should have kvs for W3C trace context for unary' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.unary(@address_msg)
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'unary should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-01'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        @stub.unary(@address_msg)
        traces = get_all_traces
        assert traces.empty?

        # without the w3c header and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        @stub.unary(@address_msg)
        traces = get_all_traces
        refute traces.empty?
      end

      # Both: Client Application cancelled the request
      it 'should report CANCELLED for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            @stub.unary_cancel(@null_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        if traces # no traces retrieved if sending them to the collector
          assert valid_edges?(traces, false), "Edges aren't valid"
          _(traces.size).must_equal 6
          assert_entry_exit(traces, 2)

          _(traces[0]['GRPCMethodType']).must_equal 'UNARY'
          traces.select { |tr| tr['Label'] =~ /exit|entry'/ }.each { |tr| _(tr['Backtrace']).must_be_nil }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
        end
      end

      # Both: Deadline expires before server returns status
      it 'should report DEADLINE_EXCEEDED for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            AppOpticsAPM::SDK.set_transaction_name('unary_deadline_exceeded')
            @stub.unary_long(@address_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        _(traces.size).must_equal 6
        assert_entry_exit(traces)
        assert valid_edges?(traces, false)

        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/unary_long'
        _(traces[0]['GRPCMethodType']).must_equal  'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| _(tr['Backtrace']).must_be_nil }
        traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }
      end

      # Client: Some data transmitted (e.g., request metadata written to TCP connection) before connection breaks
      # Server(not tested): Server shutting down
      it 'should report UNAVAILABLE for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            @unavailable.unary_unknown(@address_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        _(traces.size).must_equal 3
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces, false)

        _(traces[0]['GRPCMethodType']).must_equal  'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry'/}.each { |tr| _(tr['Backtrace']).must_be_nil }
        _(traces[2]['GRPCStatus']).must_equal      'UNAVAILABLE'
      end

      # Client: Error parsing returned status
      # Server: Application throws an exception (r something othe th returning a Status code to terminate an RPC)
      it 'should report UNKNOWN for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            @stub.unary_unknown(@address_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        _(traces.size).must_equal 6
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces[0]['GRPCMethodType']).must_equal 'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry'/ }.each { |tr| _(tr['Backtrace']).must_be_nil }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      # Client: Response cardinality violation (streaming)*
      # Server: Method not found, compression not supported*, or request cardinality violation (streaming)*
      # * not tested
      it 'should report UNIMPLEMENTED for unary' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            @stub.unary_unimplemented(@null_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        _(traces.size).must_equal 6
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces[0]['GRPCMethodType']).must_equal 'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry/ }.each { |tr| _(tr['Backtrace']).must_be_nil }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
      end

      # Client: Error parsing response proto, keepalive watchdog times out, could not decompress (algorithm supported)
      # Server: Error parsing request proto, keepalive watchdog times out, could not decompress (algorithm supported)
      # * not tested
      it 'should report INTERNAL for unary' do
        skip # hard to provoke
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            @secure.unary_2(@null_msg)
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        _(traces.size).must_equal 6
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces[0]['GRPCMethodType']).must_equal 'UNARY'
        traces.select { |tr| tr['Label'] =~ /exit|entry'/ }.each { |tr| _(tr['Backtrace']).must_be_nil }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'INTERNAL' }

        stop_secure_server
      end

      it 'sends metrics from the server for unary' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.unary', nil, is_a(Integer), is_a(Integer))
        @stub.unary(@address_msg)
        sleep 0.5
      end
    end

    describe 'CLIENT_STREAMING' do
      it 'should collect traces for client_streaming' do
        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.client_stream([@phone_msg, @phone_msg])
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 4
        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/client_stream'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'client_stream'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/client_stream'

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.client_stream'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'CLIENT_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
        traces.each { |tr| _(tr['Backtrace']).must_be_nil }
      end

      it 'should include backtraces for client_streaming if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            stub.client_stream([@phone_msg, @phone_msg])
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          assert_entry_exit(traces, 2)
          assert valid_edges?(traces, false)

          _(traces.size).must_equal 4
          _(traces[0]['Spec']).must_equal            'rsc'
          _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50052/grpctest.TestService/client_stream'
          traces.each { |tr| _(tr['GRPCMethodType']).must_equal  'CLIENT_STREAMING' }
          traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
          traces.select { |tr| tr['Label'] == 'entry'}.each { |tr| _(tr['Backtrace']).must_be_nil "Found extra backtrace!" }
          traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtrace missing!" }
        end
      end

      it 'should have kvs for W3C trace context for client_streaming' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.client_stream([@phone_msg, @phone_msg])
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'client_streaming should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-01'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        @stub.client_stream([@phone_msg, @phone_msg])
        traces = get_all_traces
        assert traces.empty?

        # without the w3c trace context and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        @stub.client_stream([@phone_msg, @phone_msg])
        traces = get_all_traces
        refute traces.empty?
      end

      it 'should report DEADLINE_EXCEEDED for client_streaming' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @no_time.client_stream_long(Array.new(5, @phone_msg))
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false) # sometimes it times out before the trace is attached

        _(traces.size).must_equal 6
        _(traces[0]['RemoteURL']).must_equal 'grpc://localhost:50051/grpctest.TestService/client_stream_long'
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'CLIENT_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }
      end

      it 'should report CANCELLED for client_streaming' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.client_stream_cancel([@null_msg, @null_msg])
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        _(traces[0]['GRPCMethodType']).must_equal 'CLIENT_STREAMING'
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
      end

      it 'should report UNAVAILABLE for client_streaming' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @unavailable.client_stream([@phone_msg, @phone_msg])
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces)

        _(traces.size).must_equal 3
        _(traces[0]['GRPCMethodType']).must_equal 'CLIENT_STREAMING'
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNAVAILABLE' }
      end

      it 'should report UNKNOWN for client_streaming' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.client_stream_unknown([@address_msg, @address_msg])
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        _(traces[0]['GRPCMethodType']).must_equal 'CLIENT_STREAMING'
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'should report UNIMPLEMENTED for client_streaming' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.client_stream_unimplemented([@phone_msg, @phone_msg])
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        _(traces[0]['GRPCMethodType']).must_equal 'CLIENT_STREAMING'
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
      end

      it 'sends metrics from the server for client_streaming' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.client_stream', nil, is_a(Integer), is_a(Integer))
        @stub.client_stream([@null_msg, @null_msg])
        sleep 0.5
      end
    end # CLIENT_STREAMING

    describe 'SERVER_STREAMING return Enumerator' do
      it 'should collect traces for server_streaming returning enumerator' do
        AppOpticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
          res.each { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 4
        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/server_stream'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'server_stream'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/server_stream'

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.server_stream'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
        traces.each { |tr| _(tr['Backtrace']).must_be_nil }
      end

      it 'should add backtraces for server_streaming with enumerator if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            res = stub.server_stream(Grpctest::AddressId.new(id: 2))
            res.each { |_| }
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          _(traces.size).must_equal 4

          traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['Backtrace']).must_be_nil "Extra backtrace in trace" }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtrace missing" }
        end
      end

      it 'should have kvs for W3C trace context for server_streaming' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
          res.each { |_| }
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'server_streaming should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-00'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
        res.each { |_| }
        traces = get_all_traces
        assert traces.empty?

        # without the w3c header and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
        res.each { |_| }
        traces = get_all_traces
        refute traces.empty?
      end

      it 'should report CANCEL for server_streaming with enumerator' do
        AppOpticsAPM::SDK.start_trace(:test) do
          res = @stub.server_stream_cancel(@null_msg)
          begin
            res.each { |_| }
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
      end

      it 'should report DEADLINE_EXCEEDED for server_streaming with enumerator' do
        AppOpticsAPM::SDK.start_trace(:test) do
          begin
            res = @no_time.server_stream_long(@null_msg)
            res.each { |_| }
          rescue => _
          end
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }
      end

      it 'should report UNAVAILABLE for server_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @unavailable.server_stream(@null_msg)
            res.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces)

        _(traces.size).must_equal 3
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNAVAILABLE' }
      end

      it 'should report UNKNOWN for server_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @stub.server_stream_unknown(@address_msg)
            res.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }

        _(traces.size).must_equal 6
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'should report UNIMPLEMENTED for server_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @stub.server_stream_unimplemented(@null_msg)
            res.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
      end

      it 'sends metrics from the server for server_streaming with enumerator' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.server_stream', nil, is_a(Integer), is_a(Integer))
        res = @stub.server_stream(@null_msg)
        res.each { |_| }
        sleep 0.5
      end
    end # SERVER_STREAMING return Enumerator

    describe 'SERVER_STREAMING yield' do
      it 'should collect traces for server_streaming using block' do
        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 4
        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/server_stream'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'server_stream'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/server_stream'

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.server_stream'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
        traces.each { |tr| _(tr['Backtrace']).must_be_nil }
      end

      it 'should add backtraces for server_streaming using block if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          _(traces.size).must_equal 4

          traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['Backtrace']).must_be_nil "Extra backtrace in trace" }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtrace missing" }
        end
      end

      it 'should have kvs for W3C trace context for server_streaming yield' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'server_streaming yield should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-00'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
        traces = get_all_traces
        assert traces.empty?

        # without the w3c header and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }
        traces = get_all_traces
        refute traces.empty?
      end

      it 'should report CANCEL for server_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.server_stream_cancel(@null_msg) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
      end

      it 'should report DEADLINE_EXCEEDED for server_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @no_time.server_stream_long(@null_msg) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }

      end

      it 'should report UNAVAILABLE for server_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @unavailable.server_stream(@null_msg) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces)

        _(traces.size).must_equal 3
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNAVAILABLE' }
      end

      it 'should report UNKNOWN for server_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @stub.server_stream_unknown(@address_msg)
            res.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'should report UNIMPLEMENTED for server_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            res = @stub.server_stream_unimplemented(@null_msg) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'SERVER_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
      end

      it 'sends metrics from the server for server_streaming using block' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.server_stream', nil, is_a(Integer), is_a(Integer))
        @stub.server_stream(@null_msg) { |_| }
        sleep 0.5
      end
    end

    describe 'BIDI_STREAMING return Enumerator' do
      it 'should collect traces for for bidi_streaming with enumerator' do
        AppOpticsAPM::SDK.start_trace(:test) do
          response = @stub.bidi_stream([@null_msg, @null_msg])
          response.each { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 4
        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/bidi_stream'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'bidi_stream'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/bidi_stream'

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.bidi_stream'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
        traces.each { |tr| _(tr['Backtrace']).must_be_nil }
      end

      it 'should add backtraces for bidi_streaming with enumerator if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            response = stub.bidi_stream([@null_msg, @null_msg])
            response.each { |_| }
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          _(traces.size).must_equal 4

          traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['Backtrace']).must_be_nil "Extra backtrace in trace" }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtrace missing" }
        end
      end

      it 'should have kvs for W3C trace context for bidi_streaming' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          response = @stub.bidi_stream([@null_msg, @null_msg])
          response.each { |_| }
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'bidi_streaming should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-00'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        response = @stub.bidi_stream([@null_msg, @null_msg])
        response.each { |_| }
        traces = get_all_traces
        assert traces.empty?

        # without the w3c header and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        response = @stub.bidi_stream([@null_msg, @null_msg])
        response.each { |_| }
        traces = get_all_traces
        refute traces.empty?
      end

      it 'should report CANCEL for bidi_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            response = @stub.bidi_stream_cancel([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
            response.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
      end

      it 'should report DEADLINE_EXCEEDED for bidi_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            response = @no_time.bidi_stream_long([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
            response.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }
      end

      it 'should report UNAVAILABLE for bidi_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            response = @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
            response.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces)

        _(traces.size).must_equal 3
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNAVAILABLE' }
      end

      it 'should report UNKNOWN for bidi_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            response = @stub.bidi_stream_unknown([@null_msg, @null_msg])
            response.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'should report UNIMPLEMENTED for bidi_streaming with enumerator' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            response = @stub.bidi_stream_unimplemented([@null_msg, @null_msg])
            response.each { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }

        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        # traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
        # version 1.18.0 returns UNKNOWN instead of UNIMPLEMENTED
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'sends metrics from the server for bidi_streaming with enumerator' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.bidi_stream', nil, is_a(Integer), is_a(Integer))
        response = @stub.bidi_stream([@null_msg, @null_msg])
        response.each { |_| }
        sleep 0.5
      end
    end

    describe 'BIDI_STREAMING yield' do
      it 'should collect traces for bidi_streaming using block' do
        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 4
        _(traces[0]['Spec']).must_equal            'rsc'
        _(traces[0]['RemoteURL']).must_equal       'grpc://localhost:50051/grpctest.TestService/bidi_stream'
        _(traces[0]['IsService']).must_equal       'True'

        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }
        _(server_entry['Spec']).must_equal            'grpc_server'
        _(server_entry['Controller']).must_equal      'AddressService'
        _(server_entry['Action']).must_equal          'bidi_stream'
        _(server_entry['URL']).must_equal             '/grpctest.TestService/bidi_stream'

        _(traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'exit' }['TransactionName']).must_equal 'AddressService.bidi_stream'

        traces.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'OK' }
        traces.each { |tr| _(tr['Backtrace']).must_be_nil }
      end

      it 'should add backtraces for bidi_streaming using block if configured' do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

        server_with_backtraces do |stub|
          AppOpticsAPM::SDK.start_trace(:test) do
            stub.bidi_stream([@phone_msg, @phone_msg]) { |_| }
          end

          traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
          _(traces.size).must_equal 4

          traces.select { |tr| tr['Label'] == 'entry' }.each { |tr| _(tr['Backtrace']).must_be_nil "Extra backtrace in trace" }
          traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['Backtrace']).wont_be_nil "Backtraces missing" }
        end
      end

      it 'should have kvs for W3C trace context for bidi_streaming yield' do
        # set up trace context
        other_state = 'aa=123'
        trace_state = AppOpticsAPM::TraceState.add_sw_member(other_state, '20a6f5ed4113e661-01')
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(@trace_00, trace_state)

        AppOpticsAPM::SDK.start_trace(:test) do
          @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
        end

        traces = get_all_traces
        client_entry = traces.find { |tr| tr['Layer'] == 'grpc-client' && tr['Label'] == 'entry' }
        server_entry = traces.find { |tr| tr['Layer'] == 'grpc-server' && tr['Label'] == 'entry' }

        # check parent_id
        assert_equal server_entry['sw.parent_id'],
                     AppOpticsAPM::TraceString.span_id(client_entry['sw.trace_context']).downcase

        # check trace_state
        assert_includes server_entry['sw.w3c.tracestate'], other_state
        assert_equal AppOpticsAPM::TraceString.span_id_flags(client_entry['sw.trace_context']),
                     AppOpticsAPM::TraceState.sw_member_value(server_entry['sw.w3c.tracestate'])
      end

      it 'bidi_streaming yield should not trace if the w3c trace context is not tracing' do
        # with a non-tracing appoptics context
        trace_parent = '00-d1169466cf4a7c3c82d07e745bb51f16-4209252012f594bf-00'
        trace_state = 'sw=4209252012f594bf-00'
        AppOpticsAPM.trace_context = AppOpticsAPM::TraceContext.new(trace_parent, trace_state)

        @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
        traces = get_all_traces
        assert traces.empty?

        # without the w3c header and no context it will always trace in testing
        AppOpticsAPM.trace_context = nil
        AppOpticsAPM::Context.clear
        @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
        traces = get_all_traces
        refute traces.empty?
      end

      it 'should report CANCEL for bidi_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.bidi_stream_cancel([@null_msg, @null_msg]) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'CANCELLED' }
      end

      it 'should report DEADLINE_EXCEEDED for bidi_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @no_time.bidi_stream_long([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'DEADLINE_EXCEEDED' }
      end

      it 'should report UNAVAILABLE for bidi_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 1)
        assert valid_edges?(traces)

        _(traces.size).must_equal 3
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNAVAILABLE' }
      end

      it 'should report UNKNOWN for bidi_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.bidi_stream_unknown([@null_msg, @null_msg]) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'should report UNIMPLEMENTED for bidi_streaming using block' do
        begin
          AppOpticsAPM::SDK.start_trace(:test) do
            @stub.bidi_stream_unimplemented([@null_msg, @null_msg]) { |_| }
          end
        rescue => _
        end

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, 2)
        assert valid_edges?(traces, false)

        _(traces.size).must_equal 6
        traces.select { |tr| tr['Label'] =~ /entry|exit/ }.each { |tr| _(tr['GRPCMethodType']).must_equal 'BIDI_STREAMING' }
        # traces.select { |tr| tr['Label'] == 'exit'}.each { |tr| _(tr['GRPCStatus']).must_equal 'UNIMPLEMENTED' }
        # version 1.18.0 returns UNKNOWN instead of UNIMPLEMENTED
        traces.select { |tr| tr['Label'] == 'exit' }.each { |tr| _(tr['GRPCStatus']).must_equal 'UNKNOWN' }
      end

      it 'sends metrics from the server for bidi_streaming using block' do
        Oboe_metal::Span.expects(:createSpan).with('AddressService.bidi_stream', nil, is_a(Integer), is_a(Integer))
        @stub.bidi_stream([@null_msg, @null_msg]) { |_| }
        sleep 0.5
      end
    end

    describe "stressing the bidi server" do
      it "should report when stressed bidi gets RESOURCE_EXHAUSTED" do
        threads = []
        @count.times do
          threads << Thread.new do
            begin
              AppOpticsAPM::SDK.start_trace(:test) do
                @stub.bidi_stream(Array.new(200, @phone_msg)) { |_| }
              end
            rescue => _
            end
          end
        end
        threads.each { |thd| thd.join }

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }

        assert_entry_exit(traces, nil, false)

        # not all calls get through, the others respond with RESOURCE_EXHAUSTED
        exhausted_count = traces.select { |tr| tr['GRPCStatus'] == 'RESOURCE_EXHAUSTED' }.size
        _(traces.size).must_equal 4*@count - exhausted_count
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

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, nil, false)

        cancelled = traces.select { |tr| tr['GRPCStatus'] =~ /CANCELLED/ }.size
        exhausted = traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED/ }.size
        _((cancelled/2 + exhausted)).must_equal @count

        _(traces.size).must_equal @count*6 - exhausted*3
      end

      it "should work when stressed bidi is unavailable" do
        AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true
        threads = []
        @count.times do
          threads << Thread.new do
            begin
              AppOpticsAPM::SDK.start_trace(:test) do
                @unavailable.bidi_stream(Array.new(200, @phone_msg)) { |_| }
              end
            rescue => _
            end
          end
        end
        threads.each { |thd| thd.join; }

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }
        assert_entry_exit(traces, @count, false)

        _(traces.size).must_equal 3*@count

        _(traces.select { |tr| tr['GRPCMethodType'] == 'BIDI_STREAMING' }.size).must_equal 2*@count
        _(traces.select { |tr| !tr['Backtrace'].nil? }.size).must_equal                    2*@count
        _(traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED|UNAVAILABLE/ }.size).must_equal @count
      end

      it "should raise and tag varying exceptions" do
        threads = []
        (3*@count).times do
          threads << Thread.new do
            begin
              AppOpticsAPM::SDK.start_trace(:test) do
                @stub.bidi_stream_varying(Array.new(20, @phone_msg)) { |_| }
              end
            rescue => _
            end
          end
        end

        sleep 0.5
        threads.each { |thd| thd.join; }

        traces = get_all_traces.delete_if { |tr| tr['Layer'] == 'test' }

        assert_entry_exit(traces, nil, false)

        # find all the exception statuses
        statuses = traces.select { |tr| tr['GRPCStatus'] }.map { |tr| [tr['GRPCStatus'], tr['Layer']] }.group_by { |ele| ele.first }
        statuses.delete('RESOURCE_EXHAUSTED') # this may not happen and it would only be reported in the client trace

        # make sure we got them all
        assert_equal ["CANCELLED", "DEADLINE_EXCEEDED", "UNIMPLEMENTED", "UNKNOWN"], statuses.keys.sort

        # make sure we have a client and a server exception status for each, except RESOURCE_EXHAUSTED
        result = statuses.find do |_, v|
          v.select { |ele| ele[1] == 'grpc-server' }.count != v.select { |ele| ele[1] == 'grpc-client' }.count
        end
        refute result
      end

    end
  end
end
