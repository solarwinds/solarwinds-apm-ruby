#Compiling the .proto file

`gprc_pb.rb` and `gprc_services_pb.rc` are generated from the `.proto` file.
The usual `protoc` command does not generate the services file.

##Prerequisits
```bash
gem install grpc
gem install grpc-tools

```
They are also in the frameworks.gemfile

##Compile
the `--grpc_flag` enables the generation of the services file
```bash
grpc_tools_ruby_protoc -I. --ruby_out=. --grpc_out=. grpc.proto
```