compiling protobufs:

make sure gems `grpc` and `grpc-tools` are installed

I'm using them with bundle and the frameworks.gemfile

This command finally created also the services_pb.rb file in the test/servers directory, the grpc directive seems to enable that:
```
bundle exec grpc_tools_ruby_protoc test/servers/grpc.proto --ruby_out . --grpc_out .
```