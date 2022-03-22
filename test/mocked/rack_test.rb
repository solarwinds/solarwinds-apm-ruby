# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'appoptics_apm/inst/rack'
require 'mocha/minitest'

describe "Rack: " do

  ##
  # HELPER METHODS
  #
  # method name = <name>_<tracestring_flags>_<expectations for start/exit/HttpSpan>
  def check_01_111(env = {})

    _, headers, _ = @rack.call(env)
    assert SolarWindsAPM::TraceString.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    assert SolarWindsAPM::TraceString.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    refute SolarWindsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces

    assert_equal 2, traces.size
    assert_equal headers['X-Trace'], traces[1]['sw.trace_context']

    SolarWindsAPM::API.expects(:log_start).once
    SolarWindsAPM::API.expects(:log_exit).once
    SolarWindsAPM::Span.expects(:createHttpSpan).once
    @rack.call(env)
  end

  def check_00_000(env = {})

    _, headers, _ = @rack.call(env)
    assert SolarWindsAPM::TraceString.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute SolarWindsAPM::TraceString.sampled?(headers['X-Trace']), 'X-Trace in headers should NOT be sampled'
    refute SolarWindsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    SolarWindsAPM::API.expects(:log_start).never
    SolarWindsAPM::API.expects(:log_exit).never
    SolarWindsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_00_001(env = {})

    _, headers, _ = @rack.call(env)
    assert SolarWindsAPM::TraceString.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute SolarWindsAPM::TraceString.sampled?(headers['X-Trace']), 'X-Trace in headers should NOT be sampled'
    refute SolarWindsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    SolarWindsAPM::API.expects(:log_start).never
    SolarWindsAPM::API.expects(:log_exit).never
    SolarWindsAPM::Span.expects(:createHttpSpan).once
    @rack.call(env)
  end

  def check_rescue_none_111(env = {})

    begin
      @rack.call(env)
    rescue
    end

    refute SolarWindsAPM::Context.isValid, 'Context after call should not be valid'

    traces = get_all_traces
    assert_equal 3, traces.size
    assert_equal 'error', traces[1]['Label']

    SolarWindsAPM::API.expects(:log_start).once
    SolarWindsAPM::API.expects(:log_exit).once
    SolarWindsAPM::Span.expects(:createHttpSpan).once
    begin
      @rack.call(env)
    rescue
    end
  end

  def check_w_context_01_110(env = {})
    SolarWindsAPM::Reporter.clear_all_traces if ENV['SW_AMP_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)
    assert SolarWindsAPM::TraceString.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    assert SolarWindsAPM::TraceString.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    assert SolarWindsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert_equal 2, traces.size
    assert_equal headers['X-Trace'], traces[1]['sw.trace_context']

    SolarWindsAPM::API.expects(:log_start).once
    SolarWindsAPM::API.expects(:log_exit).once
    SolarWindsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_w_context_00_000(env = {})
    SolarWindsAPM::Reporter.clear_all_traces if ENV['SW_AMP_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)
    assert SolarWindsAPM::TraceString.valid?(headers['X-Trace']), 'X-Trace in headers not valid'
    refute SolarWindsAPM::TraceString.sampled?(headers['X-Trace']), 'X-Trace in headers must be sampled'
    assert SolarWindsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert traces.empty?

    SolarWindsAPM::API.expects(:log_start).never
    SolarWindsAPM::API.expects(:log_exit).never
    SolarWindsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def check_w_context_none_000(env = {})
    SolarWindsAPM::Reporter.clear_all_traces if ENV['SW_AMP_REPORTER'] == 'file'

    _, headers, _ = @rack.call(env)

    refute headers.key?('X-Trace'), 'There should not be an X-Trace in headers'
    assert SolarWindsAPM::Context.isValid, 'Context after call should be valid'

    traces = get_all_traces
    assert traces.empty?, "No traces should have been recorded"

    SolarWindsAPM::API.expects(:log_start).never
    SolarWindsAPM::API.expects(:log_exit).never
    SolarWindsAPM::Span.expects(:createHttpSpan).never
    @rack.call(env)
  end

  def restart_rack
    @rack = SolarWindsAPM::Rack.new(@app)
  end

  module SolarWindsAPM
    module Config
      def self.delete(config)
        @@config.delete(config)
      end
    end
  end

  before do
    clear_all_traces
    @tr_mode = SolarWindsAPM::Config.tracing_mode
    @dnt = SolarWindsAPM::Config.dnt_compiled
    @tr_settings = SolarWindsAPM::Util.deep_dup(SolarWindsAPM::Config[:transaction_settings])
    @profiling = SolarWindsAPM::Config[:profiling]
    @backtrace = SolarWindsAPM::Config[:rack][:collect_backtraces]

    SolarWindsAPM::Config[:rack][:collect_backtraces] = false

    @app = mock('app')

    def @app.call(_)
      [200, {}, "response"]
    end

    @rack = SolarWindsAPM::Rack.new(@app)

    @trace_00 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00'
    @trace_01 = '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01'
  end

  after do
    SolarWindsAPM::Config[:tracing_mode] = @tr_mode
    SolarWindsAPM::Config[:dnt_compiled] = @dnt
    SolarWindsAPM::Config[:transaction_settings] = SolarWindsAPM::Util.deep_dup(@tr_settings)
    SolarWindsAPM::Config[:profiling] = @profiling
    SolarWindsAPM::Config[:rack][:collect_backtraces] = @backtrace

    SolarWindsAPM.trace_context = nil
  end

  after(:all) do
    WebMock.disable!
  end

  after(:all) do
    WebMock.disable!
  end

  # A and B implement the acceptance tests as outlined in the google doc
  describe 'A - tracing mode :enabled' do
    before do
      SolarWindsAPM::Config.tracing_mode = :enabled
      SolarWindsAPM::Config[:transaction_settings] = {
        url: [{ extensions: ['jpg', 'css'] },
              { regexp: '^.*\/long_job\/.*$',
                opts: Regexp::IGNORECASE,
                tracing: :disabled }]
      }
    end

    it '1 - no transaction settings' do
      SolarWindsAPM::Config.delete(:transaction_settings)

      check_01_111
    end

    it '2 - :disabled transaction settings not matched' do
      check_01_111
    end

    it '3 - :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/' }
      )
    end

    it '4 - sampling tracestate + :disabled transaction settings not matched' do
      check_01_111(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefa-00',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefa-01' }
      )
    end

    it '5 - sampling tracestate + :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-00',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefb-01' }
      )
    end

    it '6 - non-sampling tracestate + :disabled transaction settings not matched' do
      check_00_001(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefc-01',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefc-00' }
      )
    end

    it '7 - non-sampling tracestate + :disabled transaction settings matched' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefd-01',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefd-00' }
      )
    end

    it '8 - invalid tracestate + :disabled transaction settings' do
      check_00_000(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-01',
          'HTTP_TRACESTATE' => '%____sw=cb3468da6f06eefb-01' }
      )
    end

    it '9 - invalid tracestate + :enabled transaction settings' do
      check_01_111(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-00',
          'HTTP_TRACESTATE' => '%____sw=cb3468da6f06eefb-01' }
      )
    end
  end

  describe 'B - tracing mode :disabled' do
    before do
      SolarWindsAPM::Config.tracing_mode = :disabled
      SolarWindsAPM::Config[:transaction_settings] = {
        url: [{ extensions: ['jpg', 'css'],
                tracing: :enabled },
              { regexp: '^.*\/long_job\/.*$',
                opts: Regexp::IGNORECASE,
                tracing: :enabled }]
      }
    end

    it '1 - no transaction settings' do
      SolarWindsAPM::Config.delete(:transaction_settings)

      check_00_000
    end

    it '2 - :enabled transaction settings not matched' do
      check_00_000
    end

    it '3 - :enabled transaction settings matching' do
      check_01_111(
        { 'PATH_INFO' => '/long_job/' }
      )
    end

    it '4 - sampling tracestate + :enabled transaction settings not matching' do
      check_00_000(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefa-00',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefa-01' }
      )
    end

    it '5 - sampling tracestate + :enabled transaction settings matching' do
      check_01_111(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-00',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefb-01' }
      )
    end

    it '6 - non-sampling tracestate + :enabled transaction settings matching' do
      check_00_000(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefc-01',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefc-00' }
      )
    end

    it '7 - non-sampling tracestate + :enabled transaction settings not matching' do
      check_00_001(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefd-01',
          'HTTP_TRACESTATE' => 'sw=cb3468da6f06eefd-00' }
      )
    end

    it '8 - invalid tracestate + :enabled transaction settings' do
      check_01_111(
        { 'PATH_INFO' => '/long_job/',
          'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-00',
          'HTTP_TRACESTATE' => '%____sw=cb3468da6f06eefb-01' }
      )
    end

    it '9 - invalid tracestate + :disabled transaction settings' do
      check_00_000(
        { 'HTTP_TRACEPARENT' => '00-cfe479081764cc476aa983351dc51b1b-cb3468da6f06eefb-01',
          'HTTP_TRACESTATE' => '%____sw=cb3468da6f06eefb-01' }
      )
    end

  end

  describe 'C - with exceptions' do

    it 'should start/end a trace and send metrics when there is an exception' do
      def @app.call(_); raise StandardError; end

      check_rescue_none_111
    end

  end

  # the following is a common situation for grape, which,
  # when instrumented, calls SolarWindsAPM::Rack#call 3 times
  describe 'D - with context and current layer is :rack' do
    it 'calls @app.call' do
      @rack.app.expects(:call)

      SolarWindsAPM::SDK.start_trace(:rack) do
        @rack.call({})
      end
    end

    it "does not sample, do metrics, nor return X-Trace header" do
      SolarWindsAPM::SDK.start_trace(:rack) do
        check_w_context_none_000
      end
    end
  end

  describe 'E - when there is a context NOT from rack' do

    # skipping, repetition of first test in D
    # it "should call the app's call method" do
    #   @rack.app.expects(:call)
    #
    #   SolarWindsAPM::SDK.start_trace(:other) do
    #     @rack.call({})
    #   end
    # end

    it 'should sample but not do metrics' do
      SolarWindsAPM::SDK.start_trace(:other) do
        check_w_context_01_110
      end
    end

    it 'should log an error' do
      SolarWindsAPM::API.expects(:log_start)
      SolarWindsAPM::API.expects(:log_exception)
      SolarWindsAPM::API.expects(:log_exit)
      SolarWindsAPM::Span.expects(:createHttpSpan).never

      SolarWindsAPM::Context.fromString('00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01')

      assert_raises StandardError do
        def @app.call(_); raise StandardError; end
        @rack.call({})
      end
    end

    it 'returns a non sampling header when there is a non-sampling context' do
      SolarWindsAPM::Context.fromString('00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00')

      check_w_context_00_000
    end

    it 'does not trace or send metrics when there is a non-sampling context' do
      SolarWindsAPM::Context.fromString('00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00')

      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::Span.expects(:createHttpSpan).never

      @rack.call({})
    end
  end

  describe 'F - asset?' do
    it 'ignores dnt if there is no :dnt_compiled' do
      SolarWindsAPM::API.expects(:log_start).twice
      SolarWindsAPM::Span.expects(:createHttpSpan).twice

      SolarWindsAPM::Config.dnt_compiled = nil

      _, headers_1, _ = @rack.call({})
      _, headers_2, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      SolarWindsAPM::TraceString.valid?(headers_1['X-Trace'])
      SolarWindsAPM::TraceString.valid?(headers_2['X-Trace'])
      refute SolarWindsAPM::Context.isValid
    end

    it 'does not send metrics/traces when dnt matches' do
      SolarWindsAPM::API.expects(:log_start).never
      SolarWindsAPM::Span.expects(:createHttpSpan).never

      SolarWindsAPM::Config.dnt_compiled = Regexp.new('.*test$')
      restart_rack

      _, headers, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      refute headers['X-Trace']
      refute SolarWindsAPM::Context.isValid
    end

    it 'sends metrics/traces when dnt does not match' do
      SolarWindsAPM::API.expects(:log_start).once
      SolarWindsAPM::Span.expects(:createHttpSpan).once

      SolarWindsAPM::Config.dnt_compiled = Regexp.new('.*rainbow$')
      restart_rack

      _, headers, _ = @rack.call({ 'PATH_INFO' => '/blablabla/test' })

      SolarWindsAPM::TraceString.valid?(headers['X-Trace'])
      refute SolarWindsAPM::Context.isValid
    end
  end

  describe 'G - ProfileSpans KV' do
    it 'sets it to 1 if profiling is enabled' do
      SolarWindsAPM::Config['profiling'] = :enabled
      @rack.call({})
      traces = get_all_traces

      assert_equal 1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if profiling is disabled' do
      SolarWindsAPM::Config['profiling'] = :disabled
      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if the profiling config is anything else than :enabled' do
      SolarWindsAPM::Config['profiling'] = :boo
      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end

    it 'sets it to -1 if there is not profiling config' do
      SolarWindsAPM::Config.delete(:profiling)

      @rack.call({})
      traces = get_all_traces

      assert_equal -1, traces.last['ProfileSpans']
    end
  end

  describe 'H - sets a sw.tracestate_parent_id kw' do
    it 'sets the kv for a tracestate when sw is not in first position' do
      tracestate_parent_id = '49e60702469db05f'
      @rack.call({ 'HTTP_TRACEPARENT' => '00-510ae4533414d425dadf4e180d2b4e36-49e60702469db05f-00',
                   'HTTP_TRACESTATE' => "aa= 1234,sw=#{tracestate_parent_id}-01" })

      traces = get_all_traces

      assert_equal tracestate_parent_id, traces[0]['sw.tracestate_parent_id']
    end

    it 'does not set the kv when sw is not in the tracestate' do
      trace_id = '510ae4533414d425dadf4e180d2b4e36'
      span_id = '49e60702469db05f'
      @rack.call({ 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01",
                   'HTTP_TRACESTATE' => "aa= 1234,xy=111i" })

      traces = get_all_traces

      refute traces[0]['sw.tracestate_parent_id']
      assert_equal trace_id, SolarWindsAPM::TraceString.trace_id(traces[0]['sw.trace_context'])
    end

    it 'does not set the kv if there is no incoming context' do
      @rack.call({})
      traces = get_all_traces

      refute traces[0]['sw.tracestate_parent_id']
    end

    it 'does not set the kv if traceparent is not valid' do
      @rack.call({ 'HTTP_TRACEPARENT' => '35a9533414d425dadf4e180d2b4e36-49e60702469db05f-00',
                   'HTTP_TRACESTATE' => "aa= 1234,sw=49e60702469db05f-01" })

      traces = get_all_traces

      refute traces[0]['sw.tracestate_parent_id']
    end
  end

  describe 'I - sets a W3C-tracestate kw' do
    it "adds tracestate if there is a tracestate" do
      tracestate_parent_id = '49e60702469db05f'
      state = "aa= 1234,sw=#{tracestate_parent_id}-01"
      @rack.call({ 'HTTP_TRACEPARENT' => '00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-00',
                   'HTTP_TRACESTATE' => state })

      traces = get_all_traces

      assert_equal state, traces[0]['sw.w3c.tracestate']
    end

    it "does not add tracestate if there is no tracestate" do
      @rack.call({ 'HTTP_TRACEPARENT' => '00-510ae4533414d425dadf4e180d2b4e36-49e60702469db05f-00' })

      traces = get_all_traces

      refute traces[0]['sw.w3c.tracestate']
    end

  end
end
