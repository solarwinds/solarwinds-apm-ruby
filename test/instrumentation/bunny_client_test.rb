# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

unless defined?(JRUBY_VERSION)
  class BunnyClientTest < Minitest::Test
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

    def test_publish_default_exchange
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.test")
      @exchange  = @ch.default_exchange

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[1]['Layer'].must_equal "rabbitmq-client"
      traces[1]['Label'].must_equal "entry"
      traces[2]['Layer'].must_equal "rabbitmq-client"
      traces[2]['Label'].must_equal "exit"
      traces[2]['Spec'].must_equal "pushq"
      traces[2]['Flavor'].must_equal "rabbitmq"
      traces[2]['ExchangeName'].must_equal "default"
      traces[2]['RoutingKey'].must_equal "tv.ruby.test"
      traces[2]['Op'].must_equal "publish"
      traces[2]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
      traces[2].has_key?('Backtrace').must_equal !!AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]

      @conn.close
    end

    def test_publish_fanout_exchange
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.ruby.fanout.tests")

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare in the fanout exchange.", :routing_key => 'tv.ruby.test').publish("And another...")
      end

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[1]['Layer'].must_equal "rabbitmq-client"
      traces[1]['Label'].must_equal "entry"
      traces[2]['Layer'].must_equal "rabbitmq-client"
      traces[2]['Label'].must_equal "exit"
      traces[2]['Spec'].must_equal "pushq"
      traces[2]['Flavor'].must_equal "rabbitmq"
      traces[2]['ExchangeName'].must_equal "tv.ruby.fanout.tests"
      traces[2]['RoutingKey'].must_equal "tv.ruby.test"
      traces[2]['Op'].must_equal "publish"
      traces[2]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      traces[3]['Layer'].must_equal "rabbitmq-client"
      traces[3]['Label'].must_equal "entry"
      traces[4]['Layer'].must_equal "rabbitmq-client"
      traces[4]['Label'].must_equal "exit"
      traces[4]['Spec'].must_equal "pushq"
      traces[4]['Flavor'].must_equal "rabbitmq"
      traces[4]['ExchangeName'].must_equal "tv.ruby.fanout.tests"
      traces[4].key?('RoutingKey').must_equal false
      traces[4]['Op'].must_equal "publish"
      traces[4]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[4]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[4]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    def test_publish_topic_exchange
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.topic("tv.ruby.topic.tests", :auto_delete => true)

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare in the topic exchange.", :routing_key => 'tv.ruby.test.1').publish("And another...", :routing_key => 'tv.ruby.test.2' )
      end

      traces = get_all_traces
      traces.count.must_equal 6

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[1]['Layer'].must_equal "rabbitmq-client"
      traces[1]['Label'].must_equal "entry"
      traces[2]['Layer'].must_equal "rabbitmq-client"
      traces[2]['Label'].must_equal "exit"
      traces[2]['Spec'].must_equal "pushq"
      traces[2]['Flavor'].must_equal "rabbitmq"
      traces[2]['ExchangeName'].must_equal "tv.ruby.topic.tests"
      traces[2]['RoutingKey'].must_equal "tv.ruby.test.1"
      traces[2]['Op'].must_equal "publish"
      traces[2]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      traces[3]['Layer'].must_equal "rabbitmq-client"
      traces[3]['Label'].must_equal "entry"
      traces[4]['Layer'].must_equal "rabbitmq-client"
      traces[4]['Label'].must_equal "exit"
      traces[4]['Spec'].must_equal "pushq"
      traces[4]['Flavor'].must_equal "rabbitmq"
      traces[4]['ExchangeName'].must_equal "tv.ruby.topic.tests"
      traces[4]['RoutingKey'].must_equal "tv.ruby.test.2"
      traces[4]['Op'].must_equal "publish"
      traces[4]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[4]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[4]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    def test_publish_error_handling
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel

      begin
        AppOpticsAPM::API.start_trace('bunny_tests') do
          @ch = @conn.create_channel
          @ch.queue("bunny.tests.queues.auto-delete", auto_delete: true, durable: false)
          @ch.queue_declare("bunny.tests.queues.auto-delete", auto_delete: false, durable: true)
        end
      rescue
        # ignore exception and continue
      end

      traces = get_all_traces
      assert_equal 5, traces.count

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[3]['Layer'].must_equal "bunny_tests"
      traces[3]['Spec'].must_equal "error"
      traces[3]['Label'].must_equal "error"
      traces[3]['ErrorClass'].must_equal "Bunny::PreconditionFailed"
      traces[3]['ErrorMsg'].must_match(/PRECONDITION_FAILED/)
      traces[3].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]

      traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 1

      @conn.close
    end

    def test_delete_exchange
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.delete_exchange.test")
      @queue = @ch.queue("", :exclusive => true).bind(@exchange)

      @ch.confirm_select
      @exchange.publish("", :routing_key => 'tv.ruby.test')

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @exchange.delete
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, "bunny_tests")

      traces[2]['Spec'].must_equal "pushq"
      traces[2]['Flavor'].must_equal "rabbitmq"
      traces[2]['ExchangeName'].must_equal "tv.delete_exchange.test"
      traces[2]['ExchangeType'].must_equal "fanout"
      traces[2]['Op'].must_equal "delete"
      traces[2]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
    end

    def test_wait_for_confirms
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.ruby.wait_for_confirm.tests")
      @queue = @ch.queue("", :exclusive => true).bind(@exchange)

      @ch.confirm_select

      AppOpticsAPM::API.start_trace('bunny_tests') do
        1000.times do
          @exchange.publish("", :routing_key => 'tv.ruby.test')
        end

        @ch.wait_for_confirms
      end

      traces = get_all_traces
      assert_equal 2004,traces.count

      validate_outer_layers(traces, "bunny_tests")

      traces[2000]['Spec'].must_equal "pushq"
      traces[2000]['Flavor'].must_equal "rabbitmq"
      traces[2000]['ExchangeName'].must_equal "tv.ruby.wait_for_confirm.tests"
      traces[2000]['RoutingKey'].must_equal "tv.ruby.test"
      traces[2000]['Op'].must_equal "publish"
      traces[2000]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2000]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2000]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      traces[2001]['Layer'].must_equal "rabbitmq-client"
      traces[2001]['Label'].must_equal "entry"
      traces[2002]['Layer'].must_equal "rabbitmq-client"
      traces[2002]['Label'].must_equal "exit"
      traces[2002]['Spec'].must_equal "pushq"
      traces[2002]['Flavor'].must_equal "rabbitmq"
      traces[2002]['Op'].must_equal "wait_for_confirms"
      traces[2002]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2002]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2002]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    def test_channel_queue
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.queue.test")

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @queue = @ch.queue("blah", :exclusive => true).bind(@exchange)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, "bunny_tests")

      traces[2]['Spec'].must_equal "pushq"
      traces[2]['Flavor'].must_equal "rabbitmq"
      traces[2]['Op'].must_equal "queue"
      traces[2]['Queue'].must_equal "blah"
      traces[2]['RemoteHost'].must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      traces[2]['RemotePort'].must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      traces[2]['VirtualHost'].must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
    end

    def test_backtrace_config_true
      bt = AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
      AppOpticsAPM::Config[:bunnyclient][:collect_backtraces] = true

      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.test")
      @exchange  = @ch.default_exchange

      AppOpticsAPM::API.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      traces[2].has_key?('Backtrace').must_equal !!AppOpticsAPM::Config[:bunnyclient][:collect_backtraces]
      @conn.close

      AppOpticsAPM::Config[:bunnyclient][:collect_backtraces] = bt
    end
  end
end
