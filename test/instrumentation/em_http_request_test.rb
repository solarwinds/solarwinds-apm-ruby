require 'minitest_helper'

describe Oboe::Inst::EventMachine::HttpConnection do
  before do
    clear_all_traces
    @collect_backtraces = Oboe::Config[:em_http_request][:collect_backtraces]
  end

  after do
    Oboe::Config[:em_http_request][:collect_backtraces] = @collect_backtraces
  end

  it 'EventMachine::HttpConnection should be loaded, defined and ready' do
    defined?(::EventMachine::HttpConnection).wont_match nil
  end

  it 'should have oboe methods defined' do
    ::EventMachine::HttpConnection.method_defined?("setup_request_with_oboe").must_equal true
  end

  it 'should trace request' do
    Oboe::API.start_trace('em-http-request_test', '', {}) do
      EventMachine.run do
        http = EventMachine::HttpRequest.new('http://appneta.com/').get
        http.callback do
          EventMachine.stop
        end
      end
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'em-http-request_test')

    traces[1]["Layer"].must_equal "em-http-request"
    traces[1]["Label"].must_equal "entry"
    traces[1]["Uri"].must_equal "http://appneta.com/"
    traces[1].has_key?('Backtrace').must_equal Oboe::Config[:em_http_request][:collect_backtraces]

    traces[3]["Layer"].must_equal "em-http-request"
    traces[3]["Label"].must_equal "exit"
    traces[3]["Async"].must_equal "1"
    traces[3].has_key?('Backtrace').must_equal Oboe::Config[:em_http_request][:collect_backtraces]
  end

  it "should obey :collect_backtraces setting when true" do
    Oboe::Config[:em_http_request][:collect_backtraces] = true

    Oboe::API.start_trace('em-http-request_test', '', {}) do
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
    Oboe::Config[:em_http_request][:collect_backtraces] = false

    Oboe::API.start_trace('em-http-request_test', '', {}) do
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
