# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

unless defined?(JRUBY_VERSION)
  class BunnyConsumerTest < Minitest::Test
    def setup
      # Support specific environment variables to support remote rabbitmq servers
      ENV['TV_RABBITMQ_SERVER'] = "127.0.0.1"      unless ENV['TV_RABBITMQ_SERVER']
      ENV['TV_RABBITMQ_PORT'] = "5672"             unless ENV['TV_RABBITMQ_PORT']
      ENV['TV_RABBITMQ_USERNAME'] = "guest"        unless ENV['TV_RABBITMQ_USERNAME']
      ENV['TV_RABBITMQ_PASSWORD'] = "guest"        unless ENV['TV_RABBITMQ_PASSWORD']
      ENV['TV_RABBITMQ_VHOST'] = "/"               unless ENV['TV_RABBITMQ_VHOST']

      @connection_params = {}
      @connection_params[:host]   = ENV['TV_RABBITMQ_SERVER']
      @connection_params[:port]   = ENV['TV_RABBITMQ_PORT']
      @connection_params[:vhost]  = ENV['TV_RABBITMQ_VHOST']
      @connection_params[:user]   = ENV['TV_RABBITMQ_USERNAME']
      @connection_params[:pass]   = ENV['TV_RABBITMQ_PASSWORD']

      clear_all_traces
    end

    def test_consume
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.consumer.test", :exclusive => true)
      @exchange  = @ch.default_exchange

      @queue.subscribe(:block => false, :manual_ack => true) do |delivery_info, properties, payload|
        # Make an http call to spice things up
        uri = URI('http://127.0.0.1:8101/')
        http = Net::HTTP.new(uri.host, uri.port)
        http.get('/?q=1').read_body
      end

      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)

      sleep 1

      traces = get_all_traces
      traces.count.must_equal 8

      validate_outer_layers(traces, "rabbitmq-consumer")
      valid_edges?(traces)

      traces[1]['Layer'].must_equal "net-http"
      traces[1]['Label'].must_equal "entry"
      traces[6]['Layer'].must_equal "net-http"
      traces[6]['Label'].must_equal "exit"

      traces[0]['Spec'].must_equal "job"
      traces[0]['Flavor'].must_equal "rabbitmq"
      traces[0]['Queue'].must_equal "tv.ruby.consumer.test"
      traces[0]['RemoteHost'].must_equal @connection_params[:host]
      traces[0]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[0]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[0]['RoutingKey'].must_equal "tv.ruby.consumer.test"
      traces[0].key?('Backtrace').must_equal false

      @conn.close
    end

    def test_consume_error_handling
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.consumer.error.test", :exclusive => true)
      @exchange  = @ch.default_exchange

      @queue.subscribe(:block => false, :manual_ack => true) do |delivery_info, properties, payload|
        raise "blah"
      end

      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)

      sleep 1

      traces = get_all_traces
      traces.count.must_equal 3

      validate_outer_layers(traces, "rabbitmq-consumer")
      valid_edges?(traces)

      traces[0]['Spec'].must_equal "job"
      traces[0]['Flavor'].must_equal "rabbitmq"
      traces[0]['Queue'].must_equal "tv.ruby.consumer.error.test"
      traces[0]['RemoteHost'].must_equal @connection_params[:host]
      traces[0]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[0]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[0]['RoutingKey'].must_equal "tv.ruby.consumer.error.test"
      traces[0].key?('Backtrace').must_equal false

      traces[1]['Layer'].must_equal "rabbitmq-consumer"
      traces[1]['Label'].must_equal "error"
      traces[1]['ErrorClass'].must_equal "RuntimeError"
      traces[1]['ErrorMsg'].must_equal "blah"
      traces[1].key?('Backtrace').must_equal true

      traces[2]['Layer'].must_equal "rabbitmq-consumer"
      traces[2]['Label'].must_equal "exit"
    end
  end
end
