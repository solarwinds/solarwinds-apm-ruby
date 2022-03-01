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


    #====================== API server calls ==================================

    it "should trace a request to a rails api stack" do
      uri = URI.parse('http://127.0.0.1:8140/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      _(traces.count).must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        _(valid_edges?(traces)).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      _(traces[0]['Layer']).must_equal "rack"
      _(traces[0]['Label']).must_equal "entry"
      _(traces[0]['URL']).must_equal "/monkey/hello"

      _(traces[1]['Layer']).must_equal "rails-api"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[1]['Controller']).must_equal "MonkeyController"
      _(traces[1]['Action']).must_equal "hello"

      _(traces[2]['Layer']).must_equal "actionview"
      _(traces[2]['Label']).must_equal "entry"

      _(traces[3]['Layer']).must_equal "actionview"
      _(traces[3]['Label']).must_equal "exit"

      _(traces[4]['Layer']).must_equal "rails-api"
      _(traces[4]['Label']).must_equal "exit"

      _(traces[5]['Layer']).must_equal "rack"
      _(traces[5]['Label']).must_equal "exit"

      # Validate the existence of the response header
      _(r.header.key?('X-Trace')).must_equal true
      _(r.header['X-Trace']).must_equal traces[5]['sw.trace_context']
    end

    it "should capture errors" do
      uri = URI.parse('http://127.0.0.1:8140/monkey/error')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      _(traces.count).must_equal 5
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        _(valid_edges?(traces)).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      _(traces[0]['Layer']).must_equal "rack"
      _(traces[0]['Label']).must_equal "entry"
      _(traces[0]['URL']).must_equal "/monkey/error"

      _(traces[1]['Layer']).must_equal "rails-api"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[1]['Controller']).must_equal "MonkeyController"
      _(traces[1]['Action']).must_equal "error"

      _(traces[2]['Spec']).must_equal "error"
      _(traces[2]['Label']).must_equal "error"
      _(traces[2]['ErrorClass']).must_equal "RuntimeError"
      _(traces[2]['ErrorMsg']).must_equal "Rails API fake error from controller"

      _(traces.select { |trace| trace['Label'] == 'error' }.count).must_equal 1

      _(traces[3]['Layer']).must_equal "rails-api"
      _(traces[3]['Label']).must_equal "exit"

      _(traces[4]['Layer']).must_equal "rack"
      _(traces[4]['Label']).must_equal "exit"

      # Validate the existence of the response header
      _(r.header.key?('X-Trace')).must_equal true
      _(r.header['X-Trace']).must_equal traces[4]['sw.trace_context']
    end

    it "should collect backtraces when true" do
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = true

      uri = URI.parse('http://127.0.0.1:8140/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      _(traces.count).must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        _(valid_edges?(traces)).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      _(traces[0]['Layer']).must_equal "rack"
      _(traces[0]['Label']).must_equal "entry"
      _(traces[0]['URL']).must_equal "/monkey/hello"

      _(traces[1]['Layer']).must_equal "rails-api"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[1]['Controller']).must_equal "MonkeyController"
      _(traces[1]['Action']).must_equal "hello"
      _(traces[1].key?('Backtrace')).must_equal true

      _(traces[2]['Layer']).must_equal "actionview"
      _(traces[2]['Label']).must_equal "entry"

      _(traces[3]['Layer']).must_equal "actionview"
      _(traces[3]['Label']).must_equal "exit"

      _(traces[4]['Layer']).must_equal "rails-api"
      _(traces[4]['Label']).must_equal "exit"

      _(traces[5]['Layer']).must_equal "rack"
      _(traces[5]['Label']).must_equal "exit"

      # Validate the existence of the response header
      _(r.header.key?('X-Trace')).must_equal true
      _(r.header['X-Trace']).must_equal traces[5]['sw.trace_context']
    end

    it "should NOT collect backtraces when false" do
      AppOpticsAPM::Config[:action_controller_api][:collect_backtraces] = false

      uri = URI.parse('http://127.0.0.1:8140/monkey/hello')
      r = Net::HTTP.get_response(uri)

      traces = get_all_traces

      _(traces.count).must_equal 6
      unless defined?(JRUBY_VERSION)
        # We don't test this under JRuby because the Java instrumentation
        # for the DB drivers doesn't use our test reporter hence we won't
        # see all trace events. :-(  To be improved.
        _(valid_edges?(traces)).must_equal true
      end
      validate_outer_layers(traces, 'rack')

      _(traces[0]['Layer']).must_equal "rack"
      _(traces[0]['Label']).must_equal "entry"
      _(traces[0]['URL']).must_equal "/monkey/hello"

      _(traces[1]['Layer']).must_equal "rails-api"
      _(traces[1]['Label']).must_equal "entry"
      _(traces[1]['Controller']).must_equal "MonkeyController"
      _(traces[1]['Action']).must_equal "hello"
      _(traces[1].key?('Backtrace')).must_equal false

      _(traces[2]['Layer']).must_equal "actionview"
      _(traces[2]['Label']).must_equal "entry"

      _(traces[3]['Layer']).must_equal "actionview"
      _(traces[3]['Label']).must_equal "exit"

      _(traces[4]['Layer']).must_equal "rails-api"
      _(traces[4]['Label']).must_equal "exit"

      _(traces[5]['Layer']).must_equal "rack"
      _(traces[5]['Label']).must_equal "exit"

      # Validate the existence of the response header
      _(r.header.key?('X-Trace')).must_equal true
      _(r.header['X-Trace']).must_equal traces[5]['sw.trace_context']
    end

  end
end
