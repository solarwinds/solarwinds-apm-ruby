#!/usr/bin/env ruby

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
  def unary(req, _)
    ::Address.new(req.to_h).to_grpc.id
  end

  def unary_unknown(req, _)
    ::Address.find(req).to_grpc
  end

  def unary_cancel(_req, _)
    raise ::GRPC::Cancelled
  end

  def unary_long(_req, _)
    raise ::GRPC::Core::OutOfTime
  end

  ### CLIENT_STREAMING ###
  def client_stream(call)
    call.each_remote_read { |req| Phone.new(req.to_h) }
    Grpctest::NullMessage.new
  end

  def client_stream_unknown(call)
    res = []
    call.each_remote_read { |req| res << ::Address.find(req).to_grpc }
    res.first
  end

  def client_stream_cancel(_req)
    raise ::GRPC::Cancelled
  end

  def client_stream_long(_req)
    raise ::GRPC::Core::OutOfTime
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

  def server_stream_unknown(req, _)
    [::Address.find(req).to_grpc,
     ::Address.find(req).to_grpc]
  end

  def server_stream_long(_req, _unused_call)
    raise ::GRPC::Core::OutOfTime
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

  def bidi_stream_long(_req, _call)
    raise ::GRPC::Core::OutOfTime

  end

  def bidi_stream_unknown(_req, _call)
    raise StandardError
  end

  def bidi_stream_varying(_req, _call)
    raise [StandardError, ::GRPC::Core::OutOfTime, ::GRPC::Cancelled, ::GRPC::Unimplemented].sample
  end
end
