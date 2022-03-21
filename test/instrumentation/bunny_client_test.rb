# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

unless defined?(JRUBY_VERSION)
  describe 'BunnyClientTest' do
    before do
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

    it 'publish_default_exchange' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.test")
      @exchange = @ch.default_exchange

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      _(traces[1]['Layer']).must_equal "rabbitmq-client"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[2]['Layer']).must_equal "rabbitmq-client"
      _(traces[2]['Label']).must_equal "exit"
      _(traces[2]['Spec']).must_equal "pushq"
      _(traces[2]['Flavor']).must_equal "rabbitmq"
      _(traces[2]['ExchangeName']).must_equal "default"
      _(traces[2]['RoutingKey']).must_equal "tv.ruby.test"
      _(traces[2]['Op']).must_equal "publish"
      _(traces[2]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
      _(traces[2].has_key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]

      @conn.close
    end

    it 'publish_fanout_exchange' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.ruby.fanout.tests")

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare in the fanout exchange.", :routing_key => 'tv.ruby.test').publish("And another...")
      end

      traces = get_all_traces
      _(traces.count).must_equal 6

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      _(traces[1]['Layer']).must_equal "rabbitmq-client"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[2]['Layer']).must_equal "rabbitmq-client"
      _(traces[2]['Label']).must_equal "exit"
      _(traces[2]['Spec']).must_equal "pushq"
      _(traces[2]['Flavor']).must_equal "rabbitmq"
      _(traces[2]['ExchangeName']).must_equal "tv.ruby.fanout.tests"
      _(traces[2]['RoutingKey']).must_equal "tv.ruby.test"
      _(traces[2]['Op']).must_equal "publish"
      _(traces[2]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      _(traces[3]['Layer']).must_equal "rabbitmq-client"
      _(traces[3]['Label']).must_equal "entry"
      _(traces[4]['Layer']).must_equal "rabbitmq-client"
      _(traces[4]['Label']).must_equal "exit"
      _(traces[4]['Spec']).must_equal "pushq"
      _(traces[4]['Flavor']).must_equal "rabbitmq"
      _(traces[4]['ExchangeName']).must_equal "tv.ruby.fanout.tests"
      _(traces[4].key?('RoutingKey')).must_equal false
      _(traces[4]['Op']).must_equal "publish"
      _(traces[4]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[4]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[4]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    it 'publish_topic_exchange' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.topic("tv.ruby.topic.tests", :auto_delete => true)

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare in the topic exchange.", :routing_key => 'tv.ruby.test.1').publish("And another...", :routing_key => 'tv.ruby.test.2')
      end

      traces = get_all_traces
      _(traces.count).must_equal 6

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      _(traces[1]['Layer']).must_equal "rabbitmq-client"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[2]['Layer']).must_equal "rabbitmq-client"
      _(traces[2]['Label']).must_equal "exit"
      _(traces[2]['Spec']).must_equal "pushq"
      _(traces[2]['Flavor']).must_equal "rabbitmq"
      _(traces[2]['ExchangeName']).must_equal "tv.ruby.topic.tests"
      _(traces[2]['RoutingKey']).must_equal "tv.ruby.test.1"
      _(traces[2]['Op']).must_equal "publish"
      _(traces[2]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      _(traces[3]['Layer']).must_equal "rabbitmq-client"
      _(traces[3]['Label']).must_equal "entry"
      _(traces[4]['Layer']).must_equal "rabbitmq-client"
      _(traces[4]['Label']).must_equal "exit"
      _(traces[4]['Spec']).must_equal "pushq"
      _(traces[4]['Flavor']).must_equal "rabbitmq"
      _(traces[4]['ExchangeName']).must_equal "tv.ruby.topic.tests"
      _(traces[4]['RoutingKey']).must_equal "tv.ruby.test.2"
      _(traces[4]['Op']).must_equal "publish"
      _(traces[4]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[4]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[4]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    it 'publish_error_handling' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel

      begin
        SolarWindsAPM::SDK.start_trace('bunny_tests') do
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

      _(traces[2].key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]

      _(traces[3]['Layer']).must_equal "bunny_tests"
      _(traces[3]['Spec']).must_equal "error"
      _(traces[3]['Label']).must_equal "error"
      _(traces[3]['ErrorClass']).must_equal "Bunny::PreconditionFailed"
      _(traces[3]['ErrorMsg']).must_match(/PRECONDITION_FAILED/)

      _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1

      @conn.close
    end

    it 'delete_exchange' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.delete_exchange.test")
      @queue = @ch.queue("", :exclusive => true).bind(@exchange)

      @ch.confirm_select
      @exchange.publish("", :routing_key => 'tv.ruby.test')

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @exchange.delete
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, "bunny_tests")

      _(traces[2]['Spec']).must_equal "pushq"
      _(traces[2]['Flavor']).must_equal "rabbitmq"
      _(traces[2]['ExchangeName']).must_equal "tv.delete_exchange.test"
      _(traces[2]['ExchangeType']).must_equal "fanout"
      _(traces[2]['Op']).must_equal "delete"
      _(traces[2]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
    end

    it 'wait_for_confirms' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.ruby.wait_for_confirm.tests")
      @queue = @ch.queue("", :exclusive => true).bind(@exchange)

      @ch.confirm_select

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        1000.times do
          @exchange.publish("", :routing_key => 'tv.ruby.test')
        end

        @ch.wait_for_confirms
      end

      traces = get_all_traces
      assert_equal 2004, traces.count

      validate_outer_layers(traces, "bunny_tests")

      _(traces[2000]['Spec']).must_equal "pushq"
      _(traces[2000]['Flavor']).must_equal "rabbitmq"
      _(traces[2000]['ExchangeName']).must_equal "tv.ruby.wait_for_confirm.tests"
      _(traces[2000]['RoutingKey']).must_equal "tv.ruby.test"
      _(traces[2000]['Op']).must_equal "publish"
      _(traces[2000]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2000]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2000]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      _(traces[2001]['Layer']).must_equal "rabbitmq-client"
      _(traces[2001]['Label']).must_equal "entry"
      _(traces[2002]['Layer']).must_equal "rabbitmq-client"
      _(traces[2002]['Label']).must_equal "exit"
      _(traces[2002]['Spec']).must_equal "pushq"
      _(traces[2002]['Flavor']).must_equal "rabbitmq"
      _(traces[2002]['Op']).must_equal "wait_for_confirms"
      _(traces[2002]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2002]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2002]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']

      @conn.close
    end

    it 'channel_queue' do
      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @exchange = @ch.fanout("tv.queue.test")

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @queue = @ch.queue("blah", :exclusive => true).bind(@exchange)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, "bunny_tests")

      _(traces[2]['Spec']).must_equal "pushq"
      _(traces[2]['Flavor']).must_equal "rabbitmq"
      _(traces[2]['Op']).must_equal "queue"
      _(traces[2]['Queue']).must_equal "blah"
      _(traces[2]['RemoteHost']).must_equal ENV['APPOPTICS_RABBITMQ_SERVER']
      _(traces[2]['RemotePort']).must_equal ENV['APPOPTICS_RABBITMQ_PORT'].to_i
      _(traces[2]['VirtualHost']).must_equal ENV['APPOPTICS_RABBITMQ_VHOST']
    end

    it 'backtrace_config_true' do
      bt = SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
      SolarWindsAPM::Config[:bunnyclient][:collect_backtraces] = true

      @conn = Bunny.new(@connection_params)
      @conn.start
      @ch = @conn.create_channel
      @queue = @ch.queue("tv.ruby.test")
      @exchange = @ch.default_exchange

      SolarWindsAPM::SDK.start_trace('bunny_tests') do
        @exchange.publish("The Tortoise and the Hare", :routing_key => @queue.name)
      end

      traces = get_all_traces
      _(traces.count).must_equal 4

      validate_outer_layers(traces, "bunny_tests")
      assert valid_edges?(traces), "Invalid edge in traces"

      _(traces[2].has_key?('Backtrace')).must_equal !!SolarWindsAPM::Config[:bunnyclient][:collect_backtraces]
      @conn.close

      SolarWindsAPM::Config[:bunnyclient][:collect_backtraces] = bt
    end
  end
end
