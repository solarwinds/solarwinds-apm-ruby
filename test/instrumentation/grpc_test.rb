# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'grpc'
require 'minitest/hooks/default'

$LOAD_PATH.unshift(File.join(File.dirname(File.dirname(__FILE__)), 'servers/grpc'))
require 'grpc_server_50051'

describe 'GRPC' do
  before(:all) do
    @server = GRPC::RpcServer.new
    @server.add_http2_port("0.0.0.0:50051", :this_port_is_insecure)
    @server.handle(AddressService)
    @server_thread = Thread.new do
      @server.run_till_terminated
    end
  end

  before do
    clear_all_traces
    AppOpticsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01')

    @null_msg = Grpctest::NullMessage.new
    @address_msg = Grpctest::Address.new(street: 'the_street', number:  123, town: 'Mission')
    @phone_msg = Grpctest::Phone.new(number: '12345678', type: 'mobile')

    @stub = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure)
    @unavailable = Grpctest::TestService::Stub.new('localhost:50052', :this_channel_is_insecure)
    @no_time = Grpctest::TestService::Stub.new('localhost:50051', :this_channel_is_insecure, timeout: 0)

    @count = 50  ### this seems high enough to trigger a resource exhausted exception

    # secure_channel_creds = GRPC::Core::ChannelCredentials.new(certs[0], nil, nil)
    # secure_stub_opts = { channel_args: { GRPC::Core::Channel::SSL_TARGET => 'foo.test.google.fr' } }
    # @secure = GRPC::ClientStub.new("localhost:#{server_port}", secure_channel_creds, **secure_stub_opts)

    @bt = AppOpticsAPM::Config[:grpc_client][:collect_backtraces]
    AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = false
  end

  after do
    AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = @bt
  end

  after(:all) do
    @server.stop
    @server_thread.join
  end

  describe 'UNARY' do

    it 'should collect traces for unary' do
      res = @stub.unary_1(@address_msg)
      @stub.unary_2(res)

      traces = get_all_traces

      traces.size.must_equal 4
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/unary_1'
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['GRPCStatus'].must_equal      'OK'
      traces[3]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report DEADLINE_EXCEEDED for unary' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        @no_time.unary_1(@address_msg)
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/unary_1'
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report CANCELLED for unary' do
      begin
        @stub.unary_cancel(@null_msg)
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report UNAVAILABLE for unary' do
      begin
        @unavailable.unary_2(@address_msg)
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for unary' do
      begin
       @stub.unary_2(@address_msg)
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'UNARY'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for unary' do
      begin
       @stub.unary_unimplemented(@null_msg)
      rescue => _
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
      @stub.client_stream([@phone_msg, @phone_msg])

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/client_stream'
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report DEADLINE_EXCEEDED for client_streaming' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        @no_time.client_stream([@phone_msg, @phone_msg])
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/client_stream'
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report CANCELLED for client_streaming' do
      begin
        @stub.client_stream_cancel([@null_msg, @null_msg])
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report UNAVAILABLE for client_streaming' do
      begin
        @unavailable.client_stream([@phone_msg, @phone_msg])
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for client_streaming' do
      begin
        @stub.client_stream(@null_msg)
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'CLIENT_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for client_streaming' do
      begin
        @stub.client_stream_unimplemented([@phone_msg, @phone_msg])
      rescue => _
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
      res = @stub.server_stream(Grpctest::AddressId.new(id: 2))
      res.each { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/server_stream'
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for server_streaming with enumerator' do
      res = @stub.server_stream_cancel(@null_msg)
      begin
        res.each { |_| }
      rescue => _
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
        res = @no_time.server_stream(@null_msg)
        res.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for server_streaming with enumerator' do
      begin
        res = @unavailable.server_stream(@null_msg)
        res.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN  for server_streaming with enumerator' do
      begin
        res = @stub.server_stream([@null_msg, @null_msg])
        res.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for server_streaming with enumerator' do
      begin
        res = @stub.server_stream_unimplemented(@null_msg)
        res.each { |_| }
      rescue => _
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
      @stub.server_stream(Grpctest::AddressId.new(id: 2)) { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/server_stream'
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for server_streaming using block' do
      begin
        @stub.server_stream_cancel(@null_msg) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report DEADLINE_EXCEEDED for server_streaming using block' do
      begin
        @no_time.server_stream(@null_msg) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for server_streaming using block' do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true

      begin
        res = @unavailable.server_stream(@null_msg) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[1]['Backtrace'].wont_be_nil
      traces[2]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for server_streaming using block' do
      begin
        res = @stub.server_stream([@null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for server_streaming using block' do
      begin
        res = @stub.server_stream_unimplemented(@null_msg) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'SERVER_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end

  describe 'BIDI_STREAMING return Enumerator' do
    it 'should collect traces for for bidi_streaming with enumerator' do
      response = @stub.bidi_stream([@null_msg, @null_msg])
      response.each { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/bidi_stream'
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end

    it 'should report CANCEL for bidi_streaming with enumerator' do
      begin
        response = @stub.bidi_stream_cancel([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
        response.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming with enumerator' do
      begin
        response = @no_time.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
        response.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for bidi_streaming with enumerator' do
      begin
        response = @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg])
        response.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for bidi_streaming with enumerator' do
      begin
        response = @stub.bidi_stream_unknown([@null_msg, @null_msg])
        response.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for bidi_streaming with enumerator' do
      begin
        response = @stub.bidi_stream_unimplemented([@null_msg, @null_msg])
        response.each { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end

  describe 'BIDI_STREAMING yield' do
    it 'should collect traces for bidi_streaming using block' do
      @stub.bidi_stream([@null_msg, @null_msg]) { |_| }

      traces = get_all_traces

      traces.size.must_equal 2
      traces[0]['Spec'].must_equal            'rsc'
      traces[0]['RemoteURL'].must_equal       'localhost:50051/grpctest.TestService/bidi_stream'
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['GRPCStatus'].must_equal      'OK'
    end


    it 'should report CANCEL for bidi_streaming using block' do
      begin
        @stub.bidi_stream_cancel([@null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'CANCELLED'
    end

    it 'should report DEADLINE_EXCEEDED for bidi_streaming using block' do
      begin
        @no_time.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'DEADLINE_EXCEEDED'
    end

    it 'should report UNAVAILABLE for bidi_streaming using block' do
      begin
       @unavailable.bidi_stream([@null_msg, @null_msg, @null_msg, @null_msg, @null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNAVAILABLE'
    end

    it 'should report UNKNOWN for bidi_streaming using block' do
      begin
        @stub.bidi_stream_unknown([@null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNKNOWN'
    end

    it 'should report UNIMPLEMENTED for bidi_streaming using block' do
      begin
        @stub.bidi_stream_unimplemented([@null_msg, @null_msg]) { |_| }
      rescue => _
      end

      traces = get_all_traces

      traces.size.must_equal 3
      traces[0]['GRPCMethodType'].must_equal  'BIDI_STREAMING'
      traces[1]['Backtrace'].must_be_nil
      traces[2]['GRPCStatus'].must_equal      'UNIMPLEMENTED'
    end
  end

  describe "stressing the bidi_server" do
    it "should report when bidi RESOURCE_EXHAUSTED" do
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            md = AppOpticsAPM::Metadata.makeRandom(true)
            AppOpticsAPM::Context.set(md)
            @stub.bidi_stream(Array.new(200, @phone_msg)) { |_| }
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }
      traces = get_all_traces

      traces.size.must_be :>=, 2*@count

      traces.select { |tr| tr['GRPCMethodType'] == 'BIDI_STREAMING' }.size.must_equal 2*@count
      traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED|OK/  }.size.must_equal @count

      puts "  Exhausted request count: #{traces.select { |tr| tr['GRPCStatus'] =~ /RESOURCE_EXHAUSTED/  }.size}."
    end

    it "should work when stressed bidi gets CANCELLED" do
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            md = AppOpticsAPM::Metadata.makeRandom(true)
            AppOpticsAPM::Context.set(md)
            @stub.bidi_stream_cancel(Array.new(200, @phone_msg)) { |_| }
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }
      traces = get_all_traces

      traces.size.must_equal 3*@count

      traces.select { |tr| tr['GRPCMethodType'] == 'BIDI_STREAMING' }.size.must_equal 2*@count
      traces.select { |tr| tr['Backtrace'].nil? }.size.must_equal                     3*@count
      traces.select { |tr| tr['GRPCStatus'] == 'CANCELLED' }.size.must_equal            @count
    end

    it "should work when stressed bidi is UNAVAILABLE" do
      AppOpticsAPM::Config[:grpc_client][:collect_backtraces] = true
      threads = []
      @count.times do
        threads << Thread.new do
          begin
            md = AppOpticsAPM::Metadata.makeRandom(true)
            AppOpticsAPM::Context.set(md)
            @unavailable.bidi_stream(Array.new(200, @phone_msg)) { |_| }
          rescue => _
          end
        end
      end
      threads.each { |thd| thd.join; }
      traces = get_all_traces

      traces.size.must_equal 3*@count

      traces.select { |tr| tr['GRPCMethodType'] == 'BIDI_STREAMING' }.size.must_equal 2*@count
      traces.select { |tr| !tr['Backtrace'].nil? }.size.must_equal                      @count
      traces.select { |tr| tr['GRPCStatus'] == 'UNAVAILABLE' }.size.must_equal          @count
    end
  end
end