#!/usr/bin/env ruby

# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Sample gRPC server that implements the Greeter::Helloworld service.
#
# Usage: $ path/to/greeter_server.rb

this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(this_dir, 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'grpc'
require_relative './grpc_services_pb'


class PhoneNumber
  attr_accessor :number, :type
end

class AddressId
  attr_accessor :id

  def initialize
    @id = 0
  end
end

class Address
  @@id = ::AddressId.new

  def self.id_increment
    @@id.id += 1
  end

  attr_accessor :id, :street, :number, :town, :phonenumbers

  def initialize(street:, number:, town:, phonenumbers: [])
    @street = street
    @number = number
    @town = town
    @phonenumbers = phonenumbers
    @id = id_increment
  end

end

class AddressService < Grpctest::AddressService::Service

  def store(req, _)
    require 'pry'
    require 'pry-byebug'
    byebug
    id = ::Address.new(req)
    Grpctest::AddressId.new(id)
  end

  def get

  end

  def phones

  end
end

# GreeterServer is simple server that implements the Helloworld Greeter server.
class AddressServer
  class << self
    def start
      start_grpc_server
    end

    private
    def start_grpc_server
      @server = GRPC::RpcServer.new
      @server.add_http2_port("0.0.0.0:50051", :this_port_is_insecure)
      @server.handle(AddressService)
      @server.run_till_terminated
    end
  end
end

AddressServer.start