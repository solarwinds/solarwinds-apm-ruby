require 'grpc'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require_relative 'grpc_server_50051'

@pool_size = 6

puts "*** starting grpc server ***"
@server = GRPC::RpcServer.new(pool_size: @pool_size)
@server.add_http2_port("0.0.0.0:50051", :this_port_is_insecure)
@server.handle(AddressService)

puts "*** grpc server started ***"

  begin
    @server.run_till_terminated
  rescue SystemExit, Interrupt
    @server.stop
  end
sleep 0.2
