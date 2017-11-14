# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

unless defined?(JRUBY_VERSION)
  class BunnyConsumerTest < Minitest::Test
    def setup
      # Support specific environment variables to support remote rabbitmq servers
      ENV['APPOPTICS_RABBITMQ_SERVER'] = "127.0.0.1"      unless ENV['APPOPTICS_RABBITMQ_SERVER']
      ENV['APPOPTICS_RABBITMQ_PORT'] = "5672"             unless ENV['APPOPTICS_RABBITMQ_PORT']
      ENV['APPOPTICS_RABBITMQ_USERNAME'] = "guest"        unless ENV['APPOPTICS_RABBITMQ_USERNAME']
      ENV['APPOPTICS_RABBITMQ_PASSWORD'] = "guest"        unless ENV['APPOPTICS_RABBITMQ_PASSWORD']
      ENV['APPOPTICS_RABBITMQ_VHOST'] = "/"               unless ENV['APPOPTICS_RABBITMQ_VHOST']

      @connection_params = {}
      @connection_params[:host]   = ENV['APPOPTICS_RABBITMQ_SERVER']
      @connection_params[:port]   = ENV['APPOPTICS_RABBITMQ_PORT']
      @connection_params[:vhost]  = ENV['APPOPTICS_RABBITMQ_VHOST']
      @connection_params[:user]   = ENV['APPOPTICS_RABBITMQ_USERNAME']
      @connection_params[:pass]   = ENV['APPOPTICS_RABBITMQ_PASSWORD']

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

      AppOptics::API.start_trace('bunny_consume_test') do
        @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
      end

      sleep 1

      traces = get_all_traces

      traces.count.must_equal 12
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[5]['Layer'].must_equal "net-http"
      traces[5]['Label'].must_equal "entry"
      traces[10]['Layer'].must_equal "net-http"
      traces[10]['Label'].must_equal "exit"

      traces[4]['Spec'].must_equal "job"
      traces[4]['Flavor'].must_equal "rabbitmq"
      traces[4]['Queue'].must_equal "tv.ruby.consumer.test"
      traces[4]['RemoteHost'].must_equal @connection_params[:host]
      traces[4]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[4]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[4]['RoutingKey'].must_equal "tv.ruby.consumer.test"
      traces[4]['Controller'].must_equal "msg_app"
      traces[4]['Action'].must_equal "generic"
      traces[4]['URL'].must_equal "/bunny/tv.ruby.consumer.test"
      traces[4].key?('SourceTrace').must_equal true
      traces[4].key?('Backtrace').must_equal false

      @conn.close
    end

    def test_blocking_consume
      skip if RUBY_VERSION < '2.0'
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.consumer.blocking.test", :exclusive => true)
      @exchange  = @ch.default_exchange

      Thread.new {
        @queue.subscribe(:block => true, :manual_ack => true) do |delivery_info, properties, payload|
          # Make an http call to spice things up
          uri = URI('http://127.0.0.1:8101/')
          http = Net::HTTP.new(uri.host, uri.port)
          http.get('/?q=1').read_body
        end
      }

      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

      sleep 1

      traces = get_all_traces
      traces.count.must_equal 8

      validate_outer_layers(traces, "rabbitmq-consumer")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[1]['Layer'].must_equal "net-http"
      traces[1]['Label'].must_equal "entry"
      traces[6]['Layer'].must_equal "net-http"
      traces[6]['Label'].must_equal "exit"

      traces[0]['Spec'].must_equal "job"
      traces[0]['Flavor'].must_equal "rabbitmq"
      traces[0]['Queue'].must_equal "tv.ruby.consumer.blocking.test"
      traces[0]['RemoteHost'].must_equal @connection_params[:host]
      traces[0]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[0]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[0]['RoutingKey'].must_equal "tv.ruby.consumer.blocking.test"
      traces[0]['Controller'].must_equal "msg_app"
      traces[0]['Action'].must_equal "generic"
      traces[0]['URL'].must_equal "/bunny/tv.ruby.consumer.blocking.test"
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

      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

      sleep 1

      traces = get_all_traces
      traces.count.must_equal 3

      validate_outer_layers(traces, "rabbitmq-consumer")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[0]['Spec'].must_equal "job"
      traces[0]['Flavor'].must_equal "rabbitmq"
      traces[0]['Queue'].must_equal "tv.ruby.consumer.error.test"
      traces[0]['RemoteHost'].must_equal @connection_params[:host]
      traces[0]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[0]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[0]['RoutingKey'].must_equal "tv.ruby.consumer.error.test"
      traces[0]['Controller'].must_equal "msg_app"
      traces[0]['Action'].must_equal "generic"
      traces[0]['URL'].must_equal "/bunny/tv.ruby.consumer.error.test"
      traces[0].key?('Backtrace').must_equal false

      traces[1]['Layer'].must_equal "rabbitmq-consumer"
      traces[1]['Label'].must_equal "error"
      traces[1]['ErrorClass'].must_equal "RuntimeError"
      traces[1]['ErrorMsg'].must_equal "blah"
      traces[1].key?('Backtrace').must_equal true

      traces[2]['Layer'].must_equal "rabbitmq-consumer"
      traces[2]['Label'].must_equal "exit"
    end

    def test_message_id_capture
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.consumer.msgid.test", :exclusive => true)
      @exchange  = @ch.default_exchange

      @queue.subscribe(:block => false, :manual_ack => true) do |delivery_info, properties, payload|
        # Make an http call to spice things up
        uri = URI('http://127.0.0.1:8101/')
        http = Net::HTTP.new(uri.host, uri.port)
        http.get('/?q=1').read_body
      end

      AppOptics::API.start_trace('bunny_consume_test') do
        @exchange.publish("The Tortoise and the Hare", :message_id => "1234", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
      end

      sleep 1

      traces = get_all_traces

      traces.count.must_equal 12
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[4]['Spec'].must_equal "job"
      traces[4]['Flavor'].must_equal "rabbitmq"
      traces[4]['Queue'].must_equal "tv.ruby.consumer.msgid.test"
      traces[4]['RemoteHost'].must_equal @connection_params[:host]
      traces[4]['RemotePort'].must_equal @connection_params[:port].to_i
      traces[4]['VirtualHost'].must_equal @connection_params[:vhost]
      traces[4]['RoutingKey'].must_equal "tv.ruby.consumer.msgid.test"
      traces[4]['Controller'].must_equal "msg_app"
      traces[4]['Action'].must_equal "generic"
      traces[4]['URL'].must_equal "/bunny/tv.ruby.consumer.msgid.test"
      traces[4]['MsgID'].must_equal "1234"
      traces[4].key?('SourceTrace').must_equal true
      traces[4].key?('Backtrace').must_equal false

      @conn.close
    end
  end
end
