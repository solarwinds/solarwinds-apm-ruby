# Copyright (c) 2015 AppNeta, Inc.
# All rights reserved.

require 'minitest_helper'

class BunnyTest < Minitest::Test
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

  end

  def test_publish_default_exchange
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @queue = @ch.queue("tv.ruby.test")
    @exchange  = @ch.default_exchange

    clear_all_traces

    TraceView::API.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
    end

    traces = get_all_traces
    assert_equal traces.count, 4

    validate_outer_layers(traces, "bunny_tests")
    valid_edges?(traces)

    traces[1]['Layer'].must_equal "rabbitmq"
    traces[1]['Label'].must_equal "entry"
    traces[2]['Layer'].must_equal "rabbitmq"
    traces[2]['Label'].must_equal "exit"
    traces[2]['ExchangeAction'].must_equal "publish"
    traces[2]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[2]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[2]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    @conn.close
  end

  def test_publish_fanout_exchange
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @exchange = @ch.fanout("tv.ruby.fanout.tests")

    clear_all_traces

    TraceView::API.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare in the fanout exchange.").publish("And another...")
    end

    traces = get_all_traces
    assert_equal traces.count, 6

    validate_outer_layers(traces, "bunny_tests")
    valid_edges?(traces)

    traces[1]['Layer'].must_equal "rabbitmq"
    traces[1]['Label'].must_equal "entry"
    traces[2]['Layer'].must_equal "rabbitmq"
    traces[2]['Label'].must_equal "exit"
    traces[2]['ExchangeAction'].must_equal "publish"
    traces[2]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[2]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[2]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    traces[3]['Layer'].must_equal "rabbitmq"
    traces[3]['Label'].must_equal "entry"
    traces[4]['Layer'].must_equal "rabbitmq"
    traces[4]['Label'].must_equal "exit"
    traces[4]['ExchangeAction'].must_equal "publish"
    traces[4]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[4]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[4]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    @conn.close
  end

  def test_publish_topic_exchange
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @exchange = @ch.topic("tv.ruby.topic.tests", :auto_delete => true)

    clear_all_traces

    TraceView::API.start_trace('bunny_tests') do
      @exchange.publish("The Tortoise and the Hare in the topic exchange.", :routing_key => 'tv.ruby.test.1').publish("And another...", :routing_key => 'tv.ruby.test.2' )
    end

    traces = get_all_traces
    assert_equal traces.count, 6

    validate_outer_layers(traces, "bunny_tests")
    valid_edges?(traces)

    traces[1]['Layer'].must_equal "rabbitmq"
    traces[1]['Label'].must_equal "entry"
    traces[2]['Layer'].must_equal "rabbitmq"
    traces[2]['Label'].must_equal "exit"
    traces[2]['ExchangeAction'].must_equal "publish"
    traces[2]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[2]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[2]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    traces[3]['Layer'].must_equal "rabbitmq"
    traces[3]['Label'].must_equal "entry"
    traces[4]['Layer'].must_equal "rabbitmq"
    traces[4]['Label'].must_equal "exit"
    traces[4]['ExchangeAction'].must_equal "publish"
    traces[4]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[4]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[4]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    @conn.close
  end

  def test_publish_error_handling
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel

    clear_all_traces

    begin
      TraceView::API.start_trace('bunny_tests') do
        @exchange = @ch.topic("tv.ruby.error.1", :auto_delete => true)
        @exchange = @ch.fanout("tv.ruby.error.1", :auto_delete => true)
        @exchange.publish("The Tortoise and the Hare in the topic exchange.", :routing_key => 'tv.ruby.test.1').publish("And another...", :routing_key => 'tv.ruby.test.2' )
      end
    rescue
      # Capture intentional redeclaration error
    end

    traces = get_all_traces
    assert_equal traces.count, 3

    validate_outer_layers(traces, "bunny_tests")
    valid_edges?(traces)

    traces[1]['Label'].must_equal "error"
    traces[1]['ErrorClass'].must_equal "Bunny::PreconditionFailed"
    traces[1]['ErrorMsg'].must_equal "PRECONDITION_FAILED - cannot redeclare exchange 'tv.ruby.error.1' in vhost '/' with different type, durable, internal or autodelete value"
    traces[1].key?('Backtrace').must_equal true

    @conn.close
  end

  def test_wait_for_confirms
    @conn = Bunny.new(@connection_params)
    @conn.start
    @ch = @conn.create_channel
    @exchange = @ch.fanout("tv.ruby.wait_for_confirm.tests")
    @queue = @ch.queue("", :exclusive => true).bind(@exchange)

    clear_all_traces

    @ch.confirm_select

    TraceView::API.start_trace('bunny_tests') do
      1000.times do
        @exchange.publish("")
      end

      @ch.wait_for_confirms
    end

    traces = get_all_traces
    assert_equal traces.count, 2004

    validate_outer_layers(traces, "bunny_tests")

    traces[2001]['Layer'].must_equal "rabbitmq"
    traces[2001]['Label'].must_equal "entry"
    traces[2002]['Layer'].must_equal "rabbitmq"
    traces[2002]['Label'].must_equal "exit"
    traces[2002]['ExchangeAction'].must_equal "wait_for_confirms"
    traces[2002]['RemoteHost'].must_equal ENV['TV_RABBITMQ_SERVER']
    traces[2002]['RemotePort'].must_equal ENV['TV_RABBITMQ_PORT']
    traces[2002]['VirtualHost'].must_equal ENV['TV_RABBITMQ_VHOST']

    @conn.close
  end
end
