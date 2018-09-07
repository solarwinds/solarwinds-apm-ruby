# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'grpc'
require_relative '../servers/grpc/grpc_server_50051'

describe 'GRPC' do

    before do
      clear_all_traces
      AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

      @null = Grpctest::NullMessage.new
      @address = Grpctest::Address.new(street: 'the_street', number:  123, town: 'Mission')
      @phone = Grpctest::Phone.new(number: '12345678', type: 'mobile')

      @stub = Grpctest::AddressService::Stub.new('localhost:50051', :this_channel_is_insecure)
      @unavailable = Grpctest::AddressService::Stub.new('localhost:50052', :this_channel_is_insecure)
      @no_time = Grpctest::AddressService::Stub.new('localhost:50051', :this_channel_is_insecure, timeout: 0)

      @bt = AppOpticsAPM::Config[:grpc_client][:collect_backtraces]
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = false
    end

    after do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = @bt
    end

    describe 'UNARY' do

    it 'should collect traces for unary' do
      res = @stub.store_address(@address)
      @stub.get_address(res)

      traces = get_all_traces

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/store_address'
      traces[0]['GRPCMethodType'].must_equal  'UNARY'

      traces[1]['GRPCStatus'].must_equal      'OK'

      traces[3]['GRPCStatus'].must_equal      'OK'

    end

    it 'should report DEADLINE_EXCEEDED for unary' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        @no_time.store_address(@address)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/store_address'
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report CANCELLED for unary' do
      begin
        @stub.cancel(@null)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report UNAVAILABLE for unary' do
      begin
        @unavailable.get_address(@address)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for unary' do
      begin
       @stub.get_address(@address)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for unary' do
      begin
       @stub.unimplemented(@null)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end

  describe 'CLIENT_STREAMING' do
    it 'should collect traces for client_streaming' do
      @stub.add_phones([@phone, @phone])

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/add_phones'
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report DEADLINE_EXCEEDED for client_streaming' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        @no_time.add_phones([@phone, @phone])
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/add_phones'
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report CANCELLED for client_streaming' do
      begin
        @stub.client_stream_cancel([@null, @null])
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report UNAVAILABLE for client_streaming' do
      begin
        @unavailable.add_phones([@phone, @phone])
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for client_streaming' do
      begin
        @stub.add_phones(@null)
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for client_streaming' do
      begin
        @stub.client_stream_unimplemented([@phone, @phone])
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end # CLIENT_STREAMING

  describe 'SERVER_STREAMING return Enumerator' do
    it 'should collect traces for server_streaming returning enumerator' do
      res = @stub.get_phones(Grpctest::AddressId.new(id: 2))
      res.each { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/get_phones'
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for server_streaming with enumerator' do
      res = @stub.server_stream_cancel(@null)
      begin
        res.each { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report DEADLINE_EXCEEDED for server_streaming with enumerator' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        res = @no_time.get_phones(Grpctest::NullMessage.new)
        res.each { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for server_streaming with enumerator' do
      begin
        res = @unavailable.get_phones(Grpctest::NullMessage.new)
        res.each { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN  for server_streaming with enumerator' do
      begin
        res = @stub.get_phones([@null, @null])
        res.each { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for server_streaming with enumerator' do
      begin
        res = @stub.server_stream_unimplemented(Grpctest::NullMessage.new)
        res.each { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end # SERVER_STREAMING return Enumerator

  describe 'SERVER_STREAMING yield' do
    it 'should collect traces for server_streaming using block' do
      @stub.get_phones(Grpctest::AddressId.new(id: 2)) { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/get_phones'
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for server_streaming using block' do
      begin
        @stub.server_stream_cancel(Grpctest::NullMessage.new) { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report DEADLINE_EXCEEDED for server_streaming using block' do
      begin
        @no_time.get_phones(Grpctest::NullMessage.new) { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for server_streaming using block' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        res = @unavailable.get_phones(Grpctest::NullMessage.new) { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for server_streaming using block' do
      begin
        res = @stub.get_phones([@null, @null]) { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for server_streaming using block' do
      begin
        res = @stub.server_stream_unimplemented(Grpctest::NullMessage.new) { |_| }
      rescue
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end

  Minitest::Test.i_suck_and_my_tests_are_order_dependent!

  describe 'BIDI_STREAMING return Enumerator' do
    it 'should collect traces for for bidi_streaming with enumerator' do
      skip
      response = @stub.many_hellos(Helloworld::HelloBadRequest.new(name: 'world'))
      response.each { |r| puts r }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/get_phones'
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for bidi_streaming with enumerator' do
      skip
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming with enumerator' do
      skip
    end

    it 'should report UNAVAILABLE for bidi_streaming with enumerator' do
      skip
    end

    it 'should report UNKNOWN for bidi_streaming with enumerator' do
      skip
    end

    it 'should report UNIMPLEMENTED for bidi_streaming with enumerator' do
      skip
    end
  end

  describe 'BIDI_STREAMING yield' do
    it 'should collect traces for bad requests to server_streamer' do
      skip
      @stub.many_hellos(Helloworld::HelloBadRequest.new(name: 'world')) { |_| }

      traces = get_all_traces
      puts traces.pretty_inspect

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.AddressService/get_phones'
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end


    it 'should report CANCEL for bidi_streaming using block' do
      skip
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming using block' do
      skip
    end

    it 'should report UNAVAILABLE for bidi_streaming using block' do
      skip
    end

    it 'should report UNKNOWN for bidi_streaming using block' do
      skip
    end

    it 'should report UNIMPLEMENTED for bidi_streaming using block' do
      skip
    end
  end
end