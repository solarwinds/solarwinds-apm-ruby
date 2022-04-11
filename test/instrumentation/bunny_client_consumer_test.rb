# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

# While these look similar to the individual Client and Consumer test
# they focus mainly on the context propagation between client and consumer
describe 'BunnyClientConsumerTest' do
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

  it 'default exchange and consumer continues context' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("tv.ruby.clientconsumer.test", :exclusive => true)
    @exchange  = @ch.default_exchange

    @queue.subscribe(:block => false, :manual_ack => true) do |_delivery_info, _properties, _payload|
      # Make an http call to spice things up
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    SolarWindsAPM::SDK.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
    end

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 10, filter_traces(traces).pretty_inspect

    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    @conn.close
  end

  it 'default exchange and consumer exception' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("tv.ruby.clientconsumer.error.test", :exclusive => true)
    @exchange  = @ch.default_exchange

    @queue.subscribe(:block => false, :manual_ack => true) do |delivery_info, properties, payload|
      raise "blah"
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    SolarWindsAPM::SDK.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
    end

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 7, filter_traces(traces).pretty_inspect

    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    @conn.close
  end

  it 'fanout exchange and consumer continues context' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("", :exclusive => true)
    @exchange  = @ch.fanout("tv.ruby.fanout.tests")
    @queue.bind(@exchange)

    @queue.subscribe(:block => false, :manual_ack => true) do |_delivery_info, _properties, _payload|
      # Make an http call to spice things up
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    SolarWindsAPM::SDK.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
    end

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 10, filter_traces(traces).pretty_inspect

    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    @conn.close
  end

  it 'topic exchange and consumer continues context' do
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("ruby.topic", :exclusive => true)
    @exchange  = @ch.topic("tv.ruby.topic.tests", :auto_delete => true)
    @queue.bind(@exchange, :routing_key => "ruby.topic.#")

    @queue.subscribe(:block => false, :manual_ack => true) do |_delivery_info, _properties, _payload|
      # Make an http call to spice things up
      uri = URI('http://127.0.0.1:8101/')
      http = Net::HTTP.new(uri.host, uri.port)
      http.get('/?q=1').read_body
    end

    SolarWindsAPM::Context.clear
    clear_all_traces
    SolarWindsAPM::SDK.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name, :app_id => "msg_app", :type => :generic)
    end

    sleep 0.1

    traces = get_all_traces
    _(traces.count).must_equal 10, filter_traces(traces).pretty_inspect

    assert valid_edges?(traces, false), "Invalid edge in traces"
    assert same_trace_id?(traces), "more than one task_id found"

    @conn.close
  end
end
