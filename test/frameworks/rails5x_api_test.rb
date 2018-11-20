# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require "minitest_helper"

if defined?(::Rails)

  describe "Rails5xAPI" do
    before do
      clear_all_traces
      AppOpticsAPM.config_lock.synchronize {
        @tm = AppOpticsAPM::Config[:tracing_mode]
        @collect_backtraces = AppOpticsAPM::Config[:action_controller_api][:collect_backtraces]
        @sample_rate = AppOpticsAPM::Config[:sample_rate]
      }
      ENV['DBTYPE'] = "postgresql" unless ENV['DBTYPE']
    end

    after do
      AppOpticsAPM.config_lock.synchronize {
        AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = @collect_backtraces
        AppOpticsAPM::Config[:tracing_mode] = @tm
        AppOpticsAPM::Config[:sample_rate] = @sample_rate
      }
    end

    it "should trace a request to a rails api stack" do
      uri = URI.parse('http://127.0.0.1:8150/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/monkey/hello"

      traces[1]['Layer'].must_equal "rails-api"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "MonkeyController"
      traces[1]['Action'].must_equal "hello"

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails-api"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[5]['X-Trace']
    end

    it "should capture errors" do
      uri = URI.parse('http://127.0.0.1:8150/monkey/error')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 5
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/monkey/error"

      traces[1]['Layer'].must_equal "rails-api"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "MonkeyController"
      traces[1]['Action'].must_equal "error"

      traces[2]['Spec'].must_equal "error"
      traces[2]['Label'].must_equal "error"
      traces[2]['ErrorClass'].must_equal "RuntimeError"
      traces[2]['ErrorMsg'].must_equal "Rails API fake error from controller"
      traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 1

      traces[3]['Layer'].must_equal "rails-api"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rack"
      traces[4]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[4]['X-Trace']
    end

    it "should collect backtraces when true" do
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = true

      uri = URI.parse('http://127.0.0.1:8150/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/monkey/hello"

      traces[1]['Layer'].must_equal "rails-api"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "MonkeyController"
      traces[1]['Action'].must_equal "hello"
      traces[1].key?('Backtrace').must_equal true

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails-api"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[5]['X-Trace']
    end

    it "should NOT collect backtraces when false" do
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = false

      uri = URI.parse('http://127.0.0.1:8150/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      traces.count.must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        valid_edges?(traces).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      traces[0]['Layer'].must_equal "rack"
      traces[0]['Label'].must_equal "entry"
      traces[0]['URL'].must_equal "/monkey/hello"

      traces[1]['Layer'].must_equal "rails-api"
      traces[1]['Label'].must_equal "entry"
      traces[1]['Controller'].must_equal "MonkeyController"
      traces[1]['Action'].must_equal "hello"
      traces[1].key?('Backtrace').must_equal false

      traces[2]['Layer'].must_equal "actionview"
      traces[2]['Label'].must_equal "entry"

      traces[3]['Layer'].must_equal "actionview"
      traces[3]['Label'].must_equal "exit"

      traces[4]['Layer'].must_equal "rails-api"
      traces[4]['Label'].must_equal "exit"

      traces[5]['Layer'].must_equal "rack"
      traces[5]['Label'].must_equal "exit"

      # Validate the existence of the response header
      r.header.key?('X-Trace').must_equal true
      r.header['X-Trace'].must_equal traces[5]['X-Trace']
    end

    require_relative "rails_shared_tests"
  end
end
