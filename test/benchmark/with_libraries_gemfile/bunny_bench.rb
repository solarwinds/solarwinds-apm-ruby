# Copyright (c) 2017 SolarWinds, LLC.
# All rights reserved.

require 'benchmark/ips'
require_relative '../../minitest_helper'


# compare logging when testing for loaded versus tracing?
ENV['APPOPTICS_GEM_VERBOSE'] = 'false'

ENV['RABBITMQ_SERVER'] = "127.0.0.1"      unless ENV['RABBITMQ_SERVER']
ENV['RABBITMQ_PORT'] = "5672"             unless ENV['RABBITMQ_PORT']
ENV['RABBITMQ_USERNAME'] = "guest"        unless ENV['RABBITMQ_USERNAME']
ENV['RABBITMQ_PASSWORD'] = "guest"        unless ENV['RABBITMQ_PASSWORD']
ENV['RABBITMQ_VHOST'] = "/"               unless ENV['RABBITMQ_VHOST']

@connection_params = {}
@connection_params[:host]   = ENV['RABBITMQ_SERVER']
@connection_params[:port]   = ENV['RABBITMQ_PORT']
@connection_params[:vhost]  = ENV['RABBITMQ_VHOST']
@connection_params[:user]   = ENV['RABBITMQ_USERNAME']
@connection_params[:pass]   = ENV['RABBITMQ_PASSWORD']

def dostuff(exchange)
  # require 'ruby-prof'

  # profile the code
  # RubyProf.start

  n = 100

  n.times do
    exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
  end

  # result = RubyProf.stop
  # print a flat profile to text
  #   printer = RubyProf::FlatPrinter.new(result)
  #   printer.print(STDOUT)
end


Benchmark.ips do |x|
  x.config(:time => 20, :warmup => 20, :iterations => 3)
  @conn = Bunny.new(@connection_params)
  @conn.start
  @channel = @conn.create_channel
  @queue = @channel.queue("ao.ruby.test")
  @exchange = @channel.topic("ao.ruby.topic.tests", :auto_delete => true)

  x.report('bunny_pub_sampling_A') do
    ENV['TEST_AB'] = 'A'
    SolarWindsAPM.loaded = true
    SolarWindsAPM::Config[:tracing_mode] = :enabled
    SolarWindsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(@exchange)
  end
  x.report('bunny_pub_sampling_B') do
    ENV['TEST_AB'] = 'B'
    SolarWindsAPM.loaded = true
    SolarWindsAPM::Config[:tracing_mode] = :enabled
    SolarWindsAPM::Context.fromString('2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00')

    dostuff(@exchange)
  end

  x.compare!
end
