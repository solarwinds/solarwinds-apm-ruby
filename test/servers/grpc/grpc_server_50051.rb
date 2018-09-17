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

# the following is needed so that it can find the code generated from umberthe protobuf
$LOAD_PATH.unshift('.') unless $LOAD_PATH.include?('.')

require 'grpc'
require_relative './grpc_services_pb'

class Phone
  @@phones = []
  attr_accessor :number, :type

  def initialize(number:, type:)
    @number = number
    @type = type
    @@phones << self
  end

  def to_grpc
    params = {
        number: @number,
        type: @type
    }
    Grpctest::Phone.new(params)
  end
end

class AddressId
  attr_accessor :id

  def initialize(index = 0)
    @id = index
  end

  def increment
    @id += 1
    self
  end

  def to_grpc
    Grpctest::AddressId.new( id: id)
  end
end

class Address
  @@id = ::AddressId.new
  @@addresses = []

  attr_accessor :id, :street, :number, :town, :phonenumbers

  def initialize(street:, number:, town:, phonenumbers: [], id: nil)
    @street = street
    @number = number
    @town = town
    @phonenumbers = phonenumbers
    self.id = @@id.increment.dup
    @@addresses << self
  end

  def self.find(req)
    @@addresses.find { |addr| addr.id.id == req.id }
  end

  def to_grpc
    params = {
        id: @id.to_grpc,
        street: @street,
        number: @number,
        town: @town,
        phonenumbers: @phonenumbers
    }
    Grpctest::Address.new(params)
  end
end

class AddressService < Grpctest::TestService::Service

  #### UNARY ###
  def unary_1(req, _)
    ::Address.new(req).to_grpc.id
  end

  def unary_2(req, _)
    ::Address.find(req).to_grpc
  end

  def unary_cancel(_req, _)
    raise ::GRPC::Cancelled
  end

  ### CLIENT_STREAMING ###
  def client_stream(call)
    call.each_remote_read { |req| Phone.new(req) }
    Grpctest::NullMessage.new
  end

  def client_stream_cancel(_req)
    raise ::GRPC::Cancelled
  end

  # needs implementation, otherwise it returns UNKNOWN
  def client_stream_unimplemented(_req)
    raise ::GRPC::Unimplemented
  end

  ### SERVER_STREAMING ###
  def server_stream(_req, _unused_call)
    [Grpctest::Phone.new( number: '113456789', type: 'mobile'),
     Grpctest::Phone.new( number: '223456789', type: 'mobile')]
  end

  def server_stream_cancel(_req, _unused_call)
    raise ::GRPC::Cancelled
  end

  ### BIDI_STREAMING ###
  def bidi_stream(_req, call)
    call.each_remote_read { |r| r.number = (r.number.to_i * r.number.to_i ).to_s  }
    Array.new(3, Grpctest::Phone.new( number: '113456789', type: 'mobile'))
  rescue => e
    puts e.message
  end

  def bidi_stream_cancel(_req, _call)
    raise ::GRPC::Cancelled
  end

  def bidi_stream_unknown(_req, _call)
    raise StandardError
  end
end
