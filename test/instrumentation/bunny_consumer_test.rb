# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'BunnyConsumerTest' do
  before do
    # Support specific environment variables to support remote rabbitmq servers
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

    clear_all_traces
  end

  it 'sends events when consuming' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("tv.ruby.consumer.test", :exclusive => true)
    @exchange  = @ch.default_exchange

    @queue.subscribe(:block => false, :manual_ack => true) do |_delivery_info, _properties, _payload|
      # Make an http call to spice things up
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

    sleep 0.1

    traces = get_all_traces

    _(traces.count).must_equal 6, filter_traces(traces).pretty_inspect

    assert valid_edges?(traces, false), "Invalid edge in traces"

    _(traces[1]['Layer']).must_equal "net-http"
    _(traces[1]['Label']).must_equal "entry"
    _(traces[4]['Layer']).must_equal "net-http"
    _(traces[4]['Label']).must_equal "exit"

    _(traces[0]['Spec']).must_equal "job"
    _(traces[0]['Flavor']).must_equal "rabbitmq"
    _(traces[0]['Queue']).must_equal "tv.ruby.consumer.test"
    _(traces[0]['RemoteHost']).must_equal @connection_params[:host]
    _(traces[0]['RemotePort']).must_equal @connection_params[:port].to_i
    _(traces[0]['VirtualHost']).must_equal @connection_params[:vhost]
    _(traces[0]['RoutingKey']).must_equal "tv.ruby.consumer.test"
    _(traces[0]['Controller']).must_equal "msg_app"
    _(traces[0]['Action']).must_equal "generic"
    _(traces[0]['URL']).must_equal "/bunny/tv.ruby.consumer.test"
    _(traces[2].key?('sw.tracestate_parent_id')).must_equal true
    _(traces[5].key?('Backtrace')).must_equal false

    @conn.close
  end

  it 'sends event when consuming is blocked' do
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

    SolarWindsAPM::Context.clear
    clear_all_traces
    @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 6

    validate_outer_layers(traces, "rabbitmq-consumer")
    assert valid_edges?(traces, false), "Invalid edge in traces"

    _(traces[1]['Layer']).must_equal "net-http"
    _(traces[1]['Label']).must_equal "entry"
    _(traces[4]['Layer']).must_equal "net-http"
    _(traces[4]['Label']).must_equal "exit"

    _(traces[0]['Spec']).must_equal "job"
    _(traces[0]['Flavor']).must_equal "rabbitmq"
    _(traces[0]['Queue']).must_equal "tv.ruby.consumer.blocking.test"
    _(traces[0]['RemoteHost']).must_equal @connection_params[:host]
    _(traces[0]['RemotePort']).must_equal @connection_params[:port].to_i
    _(traces[0]['VirtualHost']).must_equal @connection_params[:vhost]
    _(traces[0]['RoutingKey']).must_equal "tv.ruby.consumer.blocking.test"
    _(traces[0]['Controller']).must_equal "msg_app"
    _(traces[0]['Action']).must_equal "generic"
    _(traces[0]['URL']).must_equal "/bunny/tv.ruby.consumer.blocking.test"
    _(traces[0].key?('Backtrace')).must_equal false

    @conn.close
  end

  it 'send event when there is an exception' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("tv.ruby.consumer.error.test", :exclusive => true)
    @exchange  = @ch.default_exchange

    @queue.subscribe(:block => false, :manual_ack => true) do |delivery_info, properties, payload|
      raise "blah"
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 3

    validate_outer_layers(traces, "rabbitmq-consumer")
    assert valid_edges?(traces), "Invalid edge in traces"

    _(traces[0]['Spec']).must_equal "job"
    _(traces[0]['Flavor']).must_equal "rabbitmq"
    _(traces[0]['Queue']).must_equal "tv.ruby.consumer.error.test"
    _(traces[0]['RemoteHost']).must_equal @connection_params[:host]
    _(traces[0]['RemotePort']).must_equal @connection_params[:port].to_i
    _(traces[0]['VirtualHost']).must_equal @connection_params[:vhost]
    _(traces[0]['RoutingKey']).must_equal "tv.ruby.consumer.error.test"
    _(traces[0]['Controller']).must_equal "msg_app"
    _(traces[0]['Action']).must_equal "generic"
    _(traces[0]['URL']).must_equal "/bunny/tv.ruby.consumer.error.test"
    _(traces[0].key?('Backtrace')).must_equal false

    _(traces[1]['Layer']).must_equal "rabbitmq-consumer"
    _(traces[1]['Spec']).must_equal "error"
    _(traces[1]['Label']).must_equal "error"
    _(traces[1]['ErrorClass']).must_equal "RuntimeError"
    _(traces[1]['ErrorMsg']).must_equal "blah"
    _(traces[1].key?('Backtrace')).must_equal true
    _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1

    _(traces[2]['Layer']).must_equal "rabbitmq-consumer"
    _(traces[2]['Label']).must_equal "exit"

    @conn.close
  end

  it 'captures the id' do
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

    SolarWindsAPM::Context.clear
    clear_all_traces
    @exchange.publish("The Tortoise and the Hare", :message_id => "1234", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)

    sleep 0.1

    traces = get_all_traces

    _(traces.count).must_equal 6, filter_traces(traces).pretty_inspect
    assert valid_edges?(traces, false), "Invalid edge in traces"

    _(traces[0]['Spec']).must_equal "job"
    _(traces[0]['Flavor']).must_equal "rabbitmq"
    _(traces[0]['Queue']).must_equal "tv.ruby.consumer.msgid.test"
    _(traces[0]['RemoteHost']).must_equal @connection_params[:host]
    _(traces[0]['RemotePort']).must_equal @connection_params[:port].to_i
    _(traces[0]['VirtualHost']).must_equal @connection_params[:vhost]
    _(traces[0]['RoutingKey']).must_equal "tv.ruby.consumer.msgid.test"
    _(traces[0]['Controller']).must_equal "msg_app"
    _(traces[0]['Action']).must_equal "generic"
    _(traces[0]['URL']).must_equal "/bunny/tv.ruby.consumer.msgid.test"
    _(traces[0]['MsgID']).must_equal "1234"
    # _(traces[4].key?('SourceTrace')).must_equal true
    # TODO report sw.tracestate_parent_id instead
    assert traces[2].key?('sw.tracestate_parent_id')
    _(traces[0].key?('Backtrace')).must_equal false

    @conn.close
  end
end
