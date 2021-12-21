# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

# Disable this test on JRuby until we can investigate
# "SOCKET: SET COMM INACTIVITY UNIMPLEMENTED 10"
# https://travis-ci.org/tracelytics/ruby-appoptics_apm/jobs/33745752
if AppOpticsAPM::Config[:em_http_request] && AppOpticsAPM::Config[:em_http_request][:enabled] && !defined?(JRUBY_VERSION)

  describe "EventMachine" do
    skip # we aren't supporting em-http-client anymore, not sure when it stopped
    before do
      clear_all_traces
      @collect_backtraces = AppOpticsAPM::Config[:em_http_request][:collect_backtraces]
    end

    after do
      AppOpticsAPM::Config[:em_http_request][:collect_backtraces] = @collect_backtraces
    end

    it 'EventMachine::HttpConnection should be loaded, defined and ready' do
      _(defined?(::EventMachine::HttpConnection)).wont_match nil
    end

    it 'should have appoptics_apm methods defined' do
      _(::EventMachine::HttpConnection.method_defined?("setup_request_with_appoptics")).must_equal true
    end

    it 'should trace request' do
      AppOpticsAPM::SDK.start_trace('em-http-request_test') do
        EventMachine.run do
          http = EventMachine::HttpRequest.new('http://appneta.com/').get
          http.callback do
            EventMachine.stop
          end
        end
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'em-http-request_test')

      _(traces[1]["Layer"]).must_equal "em-http-request"
      _(traces[1]["Label"]).must_equal "entry"
      _(traces[1]["Spec"]).must_equal "rsc"
      _(traces[1]["IsService"]).must_equal "1"
      _(traces[1]["RemoteURL"]).must_equal "http://appneta.com/"
      _(traces[1].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:em_http_request][:collect_backtraces]

      _(traces[2]["Layer"]).must_equal "em-http-request"
      _(traces[2]["Label"]).must_equal "exit"
      _(traces[2]["Async"]).must_equal "1"
      _(traces[2].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:em_http_request][:collect_backtraces]
    end

    it 'should log errors on exception' do
      AppOpticsAPM::SDK.start_trace('em-http-request_test') do
        EventMachine.run do
          http = EventMachine::HttpRequest.new('http://appneta.com/').get
          http.callback do
            EventMachine.stop
          end
        end
      end

      traces = get_all_traces

      _(traces.count).must_equal 4
      validate_outer_layers(traces, 'em-http-request_test')

      _(traces[1]["Layer"]).must_equal "em-http-request"
      _(traces[1]["Label"]).must_equal "entry"
      _(traces[1]["Spec"]).must_equal "rsc"
      _(traces[1]["IsService"]).must_equal "1"
      _(traces[1]["RemoteURL"]).must_equal "http://appneta.com/"
      _(traces[1].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:em_http_request][:collect_backtraces]

      _(traces[2]["Layer"]).must_equal "em-http-request"
      _(traces[2]["Label"]).must_equal "exit"
      _(traces[2]["Async"]).must_equal "1"
      _(traces[2].has_key?('Backtrace')).must_equal AppOpticsAPM::Config[:em_http_request][:collect_backtraces]
    end

    it "should obey :collect_backtraces setting when true" do
      AppOpticsAPM::Config[:em_http_request][:collect_backtraces] = true

      AppOpticsAPM::SDK.start_trace('em-http-request_test') do
        EventMachine.run do
          http = EventMachine::HttpRequest.new('http://appneta.com/').get
          http.callback do
            EventMachine.stop
          end
        end
      end

      traces = get_all_traces
      layer_has_key(traces, 'em-http-request', 'Backtrace')
    end

    it "should obey :collect_backtraces setting when false" do
      AppOpticsAPM::Config[:em_http_request][:collect_backtraces] = false

      AppOpticsAPM::SDK.start_trace('em-http-request_test') do
        EventMachine.run do
          http = EventMachine::HttpRequest.new('http://appneta.com/').get
          http.callback do
            EventMachine.stop
          end
        end
      end

      traces = get_all_traces
      layer_doesnt_have_key(traces, 'em-http-request', 'Backtrace')
    end
  end

end # unless defined?(JRUBY_VERSION)
